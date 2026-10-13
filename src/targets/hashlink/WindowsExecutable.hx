package targets.hashlink;

import haxe.io.Bytes;
import sys.FileSystem;

/** Windows PE image edits used by the HashLink package target. */
class WindowsExecutable {
	static inline var PE32 = 0x10B;
	static inline var PE32_PLUS = 0x20B;
	static inline var WINDOWS_GUI = 2;
	static inline var WINDOWS_CONSOLE = 3;

	/** Converts a console PE executable to the Windows GUI subsystem. */
	public static function setGuiSubsystem(path:String):Void {
		if(!FileSystem.exists(path) || FileSystem.isDirectory(path))
			Term.error('Cannot change Windows subsystem; executable does not exist: $path');

		var bytes:Bytes;
		try {
			bytes = sys.io.File.getBytes(path);
		}
		catch(e:Dynamic) {
			Term.error('Could not read Windows executable $path: $e');
			return;
		}

		var optional = optionalHeaderOffset(bytes, path);
		var subsystemOffset = optional + 68;
		var checksumOffset = optional + 64;
		var subsystem = u16(bytes, subsystemOffset);
		if(subsystem == WINDOWS_GUI) return;
		if(subsystem != WINDOWS_CONSOLE) {
			Term.error('Refusing to change $path: expected a console executable, found PE subsystem $subsystem.');
			return;
		}

		bytes.set(subsystemOffset, WINDOWS_GUI & 0xFF);
		bytes.set(subsystemOffset + 1, (WINDOWS_GUI >> 8) & 0xFF);
		writeU32(bytes, checksumOffset, 0);
		writeU32(bytes, checksumOffset, calculateChecksum(bytes, checksumOffset));

		try {
			sys.io.File.saveBytes(path, bytes);
		}
		catch(e:Dynamic) {
			Term.error('Could not update Windows executable $path: $e');
		}
	}

	static function optionalHeaderOffset(bytes:Bytes, path:String):Int {
		if(bytes.length < 0x40 || bytes.get(0) != 0x4D || bytes.get(1) != 0x5A)
			Term.error('Cannot change $path: it is not a Windows PE executable.');

		var pe = u32(bytes, 0x3C);
		if(pe < 0 || pe + 24 > bytes.length || u32(bytes, pe) != 0x00004550)
			Term.error('Cannot change $path: invalid PE signature.');

		var coff = pe + 4;
		var optionalSize = u16(bytes, coff + 16);
		var optional = coff + 20;
		if(optionalSize < 70 || optional + optionalSize > bytes.length)
			Term.error('Cannot change $path: invalid PE optional header.');

		var magic = u16(bytes, optional);
		if(magic != PE32 && magic != PE32_PLUS)
			Term.error('Cannot change $path: unsupported PE optional header format.');

		return optional;
	}

	static function calculateChecksum(bytes:Bytes, checksumOffset:Int):Int {
		var sum:Float = 0;
		var offset = 0;
		while(offset < bytes.length) {
			var word = 0;
			if(offset != checksumOffset && offset != checksumOffset + 2) {
				word = bytes.get(offset);
				if(offset + 1 < bytes.length) word |= bytes.get(offset + 1) << 8;
			}
			sum += word;
			sum = (sum % 0x10000) + Math.floor(sum / 0x10000);
			offset += 2;
		}
		sum = (sum % 0x10000) + Math.floor(sum / 0x10000);
		sum += bytes.length;
		return Std.int(sum);
	}

	static function writeU32(bytes:Bytes, offset:Int, value:Int):Void {
		bytes.set(offset, value & 0xFF);
		bytes.set(offset + 1, (value >> 8) & 0xFF);
		bytes.set(offset + 2, (value >> 16) & 0xFF);
		bytes.set(offset + 3, (value >> 24) & 0xFF);
	}

	static function u16(bytes:Bytes, offset:Int):Int {
		return bytes.get(offset) | (bytes.get(offset + 1) << 8);
	}

	static function u32(bytes:Bytes, offset:Int):Int {
		return bytes.get(offset) | (bytes.get(offset + 1) << 8) | (bytes.get(offset + 2) << 16) | (bytes.get(offset + 3) << 24);
	}
}
