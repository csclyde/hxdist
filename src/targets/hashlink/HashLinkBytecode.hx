package targets.hashlink;

import haxe.io.Bytes;

typedef HashLinkNative = {
	var name:String;
	var optional:Bool;
}

/**
	Reads the part of a HashLink bytecode file that describes native calls.

	The native table is part of the stable HLB module layout: each entry stores
	the string-table index of the library name and the native function name. We
	do not need to deserialize functions or opcodes, but we do need to skip the
	type section to reach the native table.
*/
class HashLinkBytecode {
	public static function natives(path:String):Array<HashLinkNative> {
		var bytes = sys.io.File.getBytes(path);
		var r = new HLReader(bytes);

		if(r.u8() != 0x48 || r.u8() != 0x4C || r.u8() != 0x42)
			throw 'Not a HashLink bytecode file: $path';

		var version = r.u8();
		if(version < 2 || version > 5)
			throw 'Unsupported HashLink bytecode version $version in $path';

		var flags = r.uindex();
		var nints = r.uindex();
		var nfloats = r.uindex();
		var nstrings = r.uindex();
		var nbytes = version >= 5 ? r.uindex() : 0;
		var ntypes = r.uindex();
		var nglobals = r.uindex();
		var nnatives = r.uindex();
		var nfunctions = r.uindex();
		var nconstants = version >= 4 ? r.uindex() : 0;
		r.uindex(); // entrypoint

		r.skipElements(nints, 4);
		r.skipElements(nfloats, 8);
		var strings = readStrings(r, nstrings);

		if(version >= 5) {
			var byteSize = r.i32();
			r.skip(byteSize);
			for(i in 0...nbytes) r.uindex();
		}

		if((flags & 1) != 0) {
			var ndebugfiles = r.uindex();
			readStrings(r, ndebugfiles);
		}

		for(i in 0...ntypes)
			skipType(r);

		for(i in 0...nglobals)
			r.index();

		var result:Array<HashLinkNative> = [];
		var seen = new Map<String, HashLinkNative>();
		for(i in 0...nnatives) {
			var library = stringAt(strings, r.index(), 'native library');
			r.index(); // native function name
			r.index(); // function type
			r.uindex(); // function index

			var optional = StringTools.startsWith(library, '?');
			if(optional) library = library.substr(1);
			if(library == '' || library == 'builtin' || library == 'std') continue;
			if(!seen.exists(library)) {
				var native:HashLinkNative = {name: library, optional: optional};
				seen.set(library, native);
				result.push(native);
			} else if(!optional) {
				seen.get(library).optional = false;
			}
		}

		return result;
	}

	static function readStrings(r:HLReader, count:Int):Array<String> {
		var size = r.i32();
		if(size < 0) throw 'Invalid HashLink string table size';
		var data = r.readBytes(size);
		var result:Array<String> = [];
		var offset = 0;
		for(i in 0...count) {
			var length = r.uindex();
			if(length < 0 || offset + length >= data.length)
				throw 'Invalid HashLink string table entry';
			if(data.get(offset + length) != 0)
				throw 'Invalid HashLink string terminator';
			result.push(data.sub(offset, length).toString());
			offset += length + 1;
		}
		return result;
	}

	static function stringAt(strings:Array<String>, index:Int, label:String):String {
		if(index < 0 || index >= strings.length)
			throw 'Invalid $label index $index';
		return strings[index];
	}

	static function skipType(r:HLReader):Void {
		var kind = r.u8();
		if(kind > 22) throw 'Unknown HashLink type kind $kind';
		switch(kind) {
			case 10, 20: // HFUN, HMETHOD
				var nargs = r.uindex();
				for(i in 0...nargs) r.index();
				r.index();
			case 11, 21: // HOBJ, HSTRUCT
				r.index(); // name
				r.index(); // super
				r.uindex(); // global
				var nfields = r.uindex();
				var nproto = r.uindex();
				var nbindings = r.uindex();
				for(i in 0...nfields) {
					r.index();
					r.index();
				}
				for(i in 0...nproto) {
					r.index();
					r.uindex();
					r.index();
				}
				for(i in 0...(nbindings * 2)) r.uindex();
			case 14, 19, 22: // HREF, HNULL, HPACKED
				r.index();
			case 15: // HVIRTUAL
				var nfields = r.uindex();
				for(i in 0...nfields) {
					r.index();
					r.index();
				}
			case 17: // HABSTRACT
				r.index();
			case 18: // HENUM
				r.index();
				r.uindex();
				var nconstructs = r.uindex();
				for(i in 0...nconstructs) {
					r.index();
					var nparams = r.uindex();
					for(j in 0...nparams) r.index();
				}
			case _: // primitive types, arrays, dynamic objects, GUIDs
		}
	}
}

private class HLReader {
	var bytes:Bytes;
	var pos:Int = 0;

	public function new(bytes:Bytes) {
		this.bytes = bytes;
	}

	public function u8():Int {
		if(pos >= bytes.length) throw 'Unexpected end of HashLink bytecode';
		return bytes.get(pos++);
	}

	public function i32():Int {
		var a = u8();
		var b = u8();
		var c = u8();
		var d = u8();
		return a | (b << 8) | (c << 16) | (d << 24);
	}

	public function index():Int {
		var b = u8();
		if((b & 0x80) == 0) return b & 0x7F;
		if((b & 0x40) == 0) {
			var value = u8() | ((b & 31) << 8);
			return (b & 0x20) == 0 ? value : -value;
		}
		var value = ((b & 31) << 24) | (u8() << 16) | (u8() << 8) | u8();
		return (b & 0x20) == 0 ? value : -value;
	}

	public function uindex():Int {
		var value = index();
		if(value < 0) throw 'Negative HashLink index';
		return value;
	}

	public function skip(size:Int):Void {
		if(size < 0 || size > bytes.length - pos)
			throw 'Invalid HashLink bytecode length';
		pos += size;
	}

	public function skipElements(count:Int, width:Int):Void {
		if(count < 0 || count > Std.int((bytes.length - pos) / width))
			throw 'Invalid HashLink table length';
		skip(count * width);
	}

	public function readBytes(size:Int):Bytes {
		if(size < 0 || size > bytes.length - pos)
			throw 'Invalid HashLink bytecode length';
		var result = bytes.sub(pos, size);
		pos += size;
		return result;
	}
}
