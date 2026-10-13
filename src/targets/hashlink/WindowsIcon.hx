package targets.hashlink;

import haxe.io.Bytes;
import haxe.io.Path;
import sys.FileSystem;

private typedef IconImage = {
	var width:Int;
	var height:Int;
	var bitCount:Int;
	var data:Bytes;
}

private typedef ResourceLeaf = {
	var data:Bytes;
	var codePage:Int;
	var reserved:Int;
}

private typedef ResourceNode = {
	var named:Bool;
	var id:Int;
	var name:String;
	var children:Array<ResourceNode>;
	var leaf:Null<ResourceLeaf>;
	var offset:Int;
	var nameOffset:Int;
	var dataEntryOffset:Int;
	var dataOffset:Int;
}

private typedef PeSection = {
	var header:Int;
	var virtualSize:Int;
	var virtualAddress:Int;
	var rawSize:Int;
	var rawPointer:Int;
}

/** Embeds Windows icon resources without an external resource editor. */
class WindowsIcon {
	static inline var RT_ICON = 3;
	static inline var RT_GROUP_ICON = 14;
	static inline var ICON_LANGUAGE = 1033;
	static inline var PE32 = 0x10B;
	static inline var PE32_PLUS = 0x20B;

	public static function apply(exePath:String, configuredBase:String):Void {
		if(configuredBase == null || configuredBase == '') return;

		var images = discover(configuredBase);
		if(images.length == 0) {
			Term.print('No Windows icon found; skipping icon update.');
			return;
		}

		Term.print('Setting exe icon from ' + configuredBase + '...');
		setIcon(exePath, images);
	}

	static function discover(base:String):Array<IconImage> {
		var extension = Path.extension(base).toLowerCase();
		if(extension == 'png') {
			if(!FileSystem.exists(base) || FileSystem.isDirectory(base))
				Term.error('Configured Windows icon does not exist: $base');
			return [readPng(base)];
		}
		if(extension == 'ico') {
			if(!FileSystem.exists(base) || FileSystem.isDirectory(base))
				Term.error('Configured Windows icon does not exist: $base');
			return readIco(base);
		}

		var directory = Path.directory(base);
		if(directory == '') directory = '.';
		var prefix = Path.withoutDirectory(base);
		var images:Array<IconImage> = [];
		if(FileSystem.exists(directory) && FileSystem.isDirectory(directory)) {
			for(name in FileSystem.readDirectory(directory)) {
				var lower = name.toLowerCase();
				var expectedPrefix = (prefix + '_').toLowerCase();
				if(!StringTools.startsWith(lower, expectedPrefix) || !StringTools.endsWith(lower, '.png'))
					continue;

				var suffix = name.substr(expectedPrefix.length, name.length - expectedPrefix.length - 4);
				if(suffix == '' || !isDigits(suffix)) continue;
				var path = Path.normalize(directory + '/' + name);
				images.push(readPng(path));
			}
		}

		if(images.length > 0) {
			images.sort(function(a, b) {
				if(a.width != b.width) return a.width - b.width;
				return a.height - b.height;
			});
			for(i in 1...images.length) {
				if(images[i - 1].width == images[i].width && images[i - 1].height == images[i].height)
					Term.error('Duplicate Windows icon size: ${images[i].width}x${images[i].height}');
			}
			return images;
		}

		var ico = base + '.ico';
		if(FileSystem.exists(ico) && !FileSystem.isDirectory(ico))
			return readIco(ico);
		return [];
	}

	static function isDigits(value:String):Bool {
		for(i in 0...value.length) {
			var code = value.charCodeAt(i);
			if(code < 48 || code > 57) return false;
		}
		return true;
	}

	static function readPng(path:String):IconImage {
		var bytes = readFile(path);
		if(bytes.length < 26 || bytes.get(0) != 0x89 || bytes.get(1) != 0x50 || bytes.get(2) != 0x4E || bytes.get(3) != 0x47
			|| bytes.get(4) != 0x0D || bytes.get(5) != 0x0A || bytes.get(6) != 0x1A || bytes.get(7) != 0x0A)
			Term.error('Icon PNG has an invalid signature: $path');
		if(bytes.get(12) != 0x49 || bytes.get(13) != 0x48 || bytes.get(14) != 0x44 || bytes.get(15) != 0x52)
			Term.error('Icon PNG is missing its IHDR header: $path');

		var width = u32be(bytes, 16);
		var height = u32be(bytes, 20);
		var bitDepth = bytes.get(24);
		var colorType = bytes.get(25);
		validateIconSize(width, height, path);
		return {
			width: width,
			height: height,
			bitCount: pngBitCount(bitDepth, colorType),
			data: bytes
		};
	}

	static function pngBitCount(bitDepth:Int, colorType:Int):Int {
		return switch(colorType) {
			case 6: bitDepth * 4;
			case 4: bitDepth * 2;
			case 2: bitDepth * 3;
			default: bitDepth;
		};
	}

	static function readIco(path:String):Array<IconImage> {
		var bytes = readFile(path);
		if(bytes.length < 6 || u16(bytes, 0) != 0 || u16(bytes, 2) != 1)
			Term.error('Icon file is not a valid Windows .ico file: $path');
		var count = u16(bytes, 4);
		if(count == 0 || 6 + count * 16 > bytes.length)
			Term.error('Icon file contains no valid images: $path');

		var result:Array<IconImage> = [];
		for(i in 0...count) {
			var entry = 6 + i * 16;
			var width = bytes.get(entry); if(width == 0) width = 256;
			var height = bytes.get(entry + 1); if(height == 0) height = 256;
			var bitCount = u16(bytes, entry + 6);
			var length = u32(bytes, entry + 8);
			var offset = u32(bytes, entry + 12);
			if(length <= 0 || offset < 0 || offset + length > bytes.length)
				Term.error('Icon file contains an invalid image entry: $path');
			validateIconSize(width, height, path);
			result.push({
				width: width,
				height: height,
				bitCount: bitCount == 0 ? 32 : bitCount,
				data: bytes.sub(offset, length)
			});
		}
		return result;
	}

	static function validateIconSize(width:Int, height:Int, path:String):Void {
		if(width <= 0 || height <= 0 || width > 256 || height > 256)
			Term.error('Windows icon image must be between 1x1 and 256x256: $path (${width}x${height})');
	}

	static function setIcon(path:String, images:Array<IconImage>):Void {
		if(!FileSystem.exists(path) || FileSystem.isDirectory(path))
			Term.error('Cannot set icon; executable does not exist: $path');

		var original = readFile(path);
		var pe = parsePe(original, path);
		var root:ResourceNode = {
			named: false, id: -1, name: null, children: [], leaf: null,
			offset: 0, nameOffset: 0, dataEntryOffset: 0, dataOffset: 0
		};
		if(pe.resourceRva != 0 && pe.resourceSize != 0) {
			var resourceOffset = rvaToFile(pe.resourceRva, pe.sections, path);
			root = readDirectory(original, resourceOffset, pe.resourceSize, pe.sections, 0, path, new Map<Int, Bool>());
		}

		root.children = root.children.filter(function(node) return !(node.id == RT_ICON || node.id == RT_GROUP_ICON));
		root.children.push(iconResources(images));
		root.children.push(groupResources(images));

		var last = pe.sections[0];
		var rawEnd = last.rawPointer + last.rawSize;
		for(section in pe.sections) {
			if(section.rawPointer + section.rawSize > rawEnd) {
				last = section;
				rawEnd = section.rawPointer + section.rawSize;
			}
		}
		if(original.length < rawEnd)
			Term.error('Cannot add icon to $path: PE section extends beyond the file.');
		if(original.length > rawEnd) {
			for(i in rawEnd...original.length)
				if(original.get(i) != 0)
					Term.error('Cannot add icon to $path: unsupported PE overlay or certificate data.');
		}

		var start = align(original.length, 4);
		var resourceRva = last.virtualAddress + start - last.rawPointer;
		var resource = buildResource(root, resourceRva);
		var fileAlignment = pe.fileAlignment;
		var newRawSize = align(start + resource.length - last.rawPointer, fileAlignment);
		var newLength = last.rawPointer + newRawSize;
		var output = Bytes.alloc(newLength);
		for(i in 0...original.length) output.set(i, original.get(i));
		for(i in 0...resource.length) output.set(start + i, resource.get(i));

		writeU32(output, last.header + 8, Std.int(Math.max(last.virtualSize, start + resource.length - last.rawPointer)));
		writeU32(output, last.header + 16, newRawSize);
		writeU32(output, pe.resourceDirectory + 8, resourceRva);
		writeU32(output, pe.resourceDirectory + 12, resource.length);

		var imageEnd = 0;
		for(section in pe.sections) {
			var virtualSize = section == last ? Std.int(Math.max(last.virtualSize, start + resource.length - last.rawPointer)) : section.virtualSize;
			var rawSize = section == last ? newRawSize : section.rawSize;
			var end = align(section.virtualAddress + Std.int(Math.max(virtualSize, rawSize)), pe.sectionAlignment);
			if(end > imageEnd) imageEnd = end;
		}
		writeU32(output, pe.optionalHeader + 56, imageEnd);
		fixChecksum(output, pe.optionalHeader + 64);
		try {
			sys.io.File.saveBytes(path, output);
		}
		catch(e:Dynamic) {
			Term.error('Could not write icon resources to $path: $e');
		}
	}

	static function iconResources(images:Array<IconImage>):ResourceNode {
		var type:ResourceNode = directoryNode(false, RT_ICON, null);
		for(i in 0...images.length) {
			var name = directoryNode(false, i + 1, null);
			name.children.push(resourceLeafNode(false, ICON_LANGUAGE, null, images[i].data));
			type.children.push(name);
		}
		return type;
	}

	static function groupResources(images:Array<IconImage>):ResourceNode {
		var group = Bytes.alloc(6 + images.length * 14);
		writeU16(group, 0, 0);
		writeU16(group, 2, 1);
		writeU16(group, 4, images.length);
		for(i in 0...images.length) {
			var image = images[i];
			var offset = 6 + i * 14;
			group.set(offset, image.width == 256 ? 0 : image.width);
			group.set(offset + 1, image.height == 256 ? 0 : image.height);
			group.set(offset + 2, 0);
			group.set(offset + 3, 0);
			writeU16(group, offset + 4, 1);
			writeU16(group, offset + 6, image.bitCount);
			writeU32(group, offset + 8, image.data.length);
			writeU16(group, offset + 12, i + 1);
		}

		var type = directoryNode(false, RT_GROUP_ICON, null);
		var name = directoryNode(false, 1, null);
		name.children.push(resourceLeafNode(false, ICON_LANGUAGE, null, group));
		type.children.push(name);
		return type;
	}

	static function directoryNode(named:Bool, id:Int, name:String):ResourceNode {
		return {named: named, id: id, name: name, children: [], leaf: null, offset: 0, nameOffset: 0, dataEntryOffset: 0, dataOffset: 0};
	}

	static function resourceLeafNode(named:Bool, id:Int, name:String, data:Bytes):ResourceNode {
		return {named: named, id: id, name: name, children: [], leaf: {data: data, codePage: 0, reserved: 0}, offset: 0, nameOffset: 0, dataEntryOffset: 0, dataOffset: 0};
	}

	static function parsePe(bytes:Bytes, path:String):Dynamic {
		if(bytes.length < 0x40 || bytes.get(0) != 0x4D || bytes.get(1) != 0x5A)
			Term.error('Cannot set icon in $path: it is not a Windows PE executable.');
		var peOffset = u32(bytes, 0x3C);
		if(peOffset < 0 || peOffset + 24 > bytes.length || u32(bytes, peOffset) != 0x00004550)
			Term.error('Cannot set icon in $path: invalid PE signature.');
		var coff = peOffset + 4;
		var count = u16(bytes, coff + 2);
		var optionalSize = u16(bytes, coff + 16);
		var optional = coff + 20;
		if(optionalSize < 2 || optionalSize > bytes.length - optional)
			Term.error('Cannot set icon in $path: invalid PE optional header.');
		var magic = u16(bytes, optional);
		var dataDirectory = magic == PE32 ? optional + 96 : magic == PE32_PLUS ? optional + 112 : -1;
		if(dataDirectory < 0 || optionalSize < (dataDirectory - optional) + 24)
			Term.error('Cannot set icon in $path: unsupported PE optional header.');
		var sectionAlignment = u32(bytes, optional + 32);
		var fileAlignment = u32(bytes, optional + 36);
		if(count == 0 || sectionAlignment <= 0 || fileAlignment <= 0)
			Term.error('Cannot set icon in $path: invalid PE sections or alignment.');
		var sectionTable = optional + optionalSize;
		var sections:Array<PeSection> = [];
		for(i in 0...count) {
			var header = sectionTable + i * 40;
			if(header + 40 > bytes.length)
				Term.error('Cannot set icon in $path: invalid PE section table.');
			sections.push({
				header: header,
				virtualSize: u32(bytes, header + 8),
				virtualAddress: u32(bytes, header + 12),
				rawSize: u32(bytes, header + 16),
				rawPointer: u32(bytes, header + 20)
			});
		}
		return {
			optionalHeader: optional,
			resourceDirectory: dataDirectory + 16,
			resourceRva: u32(bytes, dataDirectory + 16),
			resourceSize: u32(bytes, dataDirectory + 20),
			sectionAlignment: sectionAlignment,
			fileAlignment: fileAlignment,
			sections: sections
		};
	}

	static function readDirectory(bytes:Bytes, base:Int, size:Int, sections:Array<PeSection>, offset:Int, path:String, seen:Map<Int, Bool>):ResourceNode {
		if(base < 0 || size < 0 || base > bytes.length || size > bytes.length - base)
			Term.error('Cannot read icon resources from $path: resource directory is outside the file.');
		if(offset < 0 || offset + 16 > size)
			Term.error('Cannot read icon resources from $path: invalid resource directory.');
		if(seen.exists(offset))
			Term.error('Cannot read icon resources from $path: cyclic resource directory.');
		seen.set(offset, true);
		var namedCount = u16(bytes, base + offset + 12);
		var idCount = u16(bytes, base + offset + 14);
		var total = namedCount + idCount;
		if(offset + 16 + total * 8 > size)
			Term.error('Cannot read icon resources from $path: truncated resource directory.');
		var node = directoryNode(false, -1, null);
		for(i in 0...total) {
			var entry = base + offset + 16 + i * 8;
			var nameField = u32(bytes, entry);
			var named = (nameField & 0x80000000) != 0;
			var childName:String = null;
			var childId = -1;
			if(named) childName = readResourceName(bytes, base, size, nameField & 0x7FFFFFFF, path);
			else childId = nameField;

			var dataField = u32(bytes, entry + 4);
			var child:ResourceNode;
			if((dataField & 0x80000000) != 0) {
				child = readDirectory(bytes, base, size, sections, dataField & 0x7FFFFFFF, path, seen);
				child.named = named;
				child.id = childId;
				child.name = childName;
			}
			else {
				var dataEntry = dataField;
				if(dataEntry < 0 || dataEntry + 16 > size)
					Term.error('Cannot read icon resources from $path: invalid resource data entry.');
				var dataRva = u32(bytes, base + dataEntry);
				var dataLength = u32(bytes, base + dataEntry + 4);
				var fileOffset = rvaToFile(dataRva, sections, path);
				if(dataLength < 0 || fileOffset < 0 || fileOffset > bytes.length || dataLength > bytes.length - fileOffset)
					Term.error('Cannot read icon resources from $path: resource data is outside the file.');
				child = resourceLeafNode(named, childId, childName, bytes.sub(fileOffset, dataLength));
				child.leaf.codePage = u32(bytes, base + dataEntry + 8);
				child.leaf.reserved = u32(bytes, base + dataEntry + 12);
			}
			node.children.push(child);
		}
		return node;
	}

	static function readResourceName(bytes:Bytes, base:Int, size:Int, offset:Int, path:String):String {
		if(offset < 0 || offset + 2 > size)
			Term.error('Cannot read icon resources from $path: invalid resource name.');
		var length = u16(bytes, base + offset);
		if(offset + 2 + length * 2 > size)
			Term.error('Cannot read icon resources from $path: truncated resource name.');
		var result = '';
		for(i in 0...length) result += String.fromCharCode(u16(bytes, base + offset + 2 + i * 2));
		return result;
	}

	static function buildResource(root:ResourceNode, resourceRva:Int):Bytes {
		sortDirectory(root);
		var cursor = 0;
		assignDirectories(root, cursor);
		cursor = directoryEnd(root);
		cursor = assignNames(root, cursor);
		assignDataEntries(root, cursor);
		cursor = dataEntriesEnd(root);
		cursor = align(cursor, 4);
		assignData(root, cursor);
		cursor = dataEnd(root);

		var output = Bytes.alloc(cursor);
		writeDirectories(output, root);
		writeNames(output, root);
		writeDataEntries(output, root, resourceRva);
		writeData(output, root);
		return output;
	}

	static function sortDirectory(node:ResourceNode):Void {
		node.children.sort(function(a, b) {
			if(a.named != b.named) return a.named ? -1 : 1;
			if(a.named) return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
			return a.id - b.id;
		});
		for(child in node.children) if(child.leaf == null) sortDirectory(child);
	}

	static function assignDirectories(node:ResourceNode, cursor:Int):Int {
		node.offset = cursor;
		cursor += 16 + node.children.length * 8;
		for(child in node.children) if(child.leaf == null) cursor = assignDirectories(child, cursor);
		return cursor;
	}

	static function directoryEnd(node:ResourceNode):Int {
		var end = node.offset + 16 + node.children.length * 8;
		for(child in node.children) if(child.leaf == null) end = Std.int(Math.max(end, directoryEnd(child)));
		return end;
	}

	static function assignNames(node:ResourceNode, cursor:Int):Int {
		for(child in node.children) {
			if(child.named) {
				child.nameOffset = cursor;
				cursor += 2 + child.name.length * 2;
			}
			if(child.leaf == null) cursor = assignNames(child, cursor);
		}
		return cursor;
	}

	static function namesEnd(node:ResourceNode):Int {
		var end = 0;
		for(child in node.children) {
			if(child.named) end = Std.int(Math.max(end, child.nameOffset + 2 + child.name.length * 2));
			if(child.leaf == null) end = Std.int(Math.max(end, namesEnd(child)));
		}
		return end;
	}

	static function assignDataEntries(node:ResourceNode, cursor:Int):Int {
		if(node.leaf != null) {
			node.dataEntryOffset = cursor;
			return cursor + 16;
		}
		for(child in node.children) cursor = assignDataEntries(child, cursor);
		return cursor;
	}

	static function dataEntriesEnd(node:ResourceNode):Int {
		if(node.leaf != null) return node.dataEntryOffset + 16;
		var end = 0;
		for(child in node.children) end = Std.int(Math.max(end, dataEntriesEnd(child)));
		return end;
	}

	static function assignData(node:ResourceNode, cursor:Int):Int {
		if(node.leaf != null) {
			node.dataOffset = cursor;
			return align(cursor + node.leaf.data.length, 4);
		}
		for(child in node.children) cursor = assignData(child, cursor);
		return cursor;
	}

	static function dataEnd(node:ResourceNode):Int {
		if(node.leaf != null) return align(node.dataOffset + node.leaf.data.length, 4);
		var end = 0;
		for(child in node.children) end = Std.int(Math.max(end, dataEnd(child)));
		return end;
	}

	static function writeDirectories(output:Bytes, node:ResourceNode):Void {
		var named = 0;
		for(child in node.children) if(child.named) named++;
		writeU16(output, node.offset + 12, named);
		writeU16(output, node.offset + 14, node.children.length - named);
		for(i in 0...node.children.length) {
			var child = node.children[i];
			var entry = node.offset + 16 + i * 8;
			writeU32(output, entry, child.named ? (0x80000000 | child.nameOffset) : child.id);
			writeU32(output, entry + 4, child.leaf == null ? (0x80000000 | child.offset) : child.dataEntryOffset);
			if(child.leaf == null) writeDirectories(output, child);
		}
	}

	static function writeNames(output:Bytes, node:ResourceNode):Void {
		for(child in node.children) {
			if(child.named) {
				writeU16(output, child.nameOffset, child.name.length);
				for(i in 0...child.name.length) writeU16(output, child.nameOffset + 2 + i * 2, child.name.charCodeAt(i));
			}
			if(child.leaf == null) writeNames(output, child);
		}
	}

	static function writeDataEntries(output:Bytes, node:ResourceNode, resourceRva:Int):Void {
		if(node.leaf != null) {
			writeU32(output, node.dataEntryOffset, resourceRva + node.dataOffset);
			writeU32(output, node.dataEntryOffset + 4, node.leaf.data.length);
			writeU32(output, node.dataEntryOffset + 8, node.leaf.codePage);
			writeU32(output, node.dataEntryOffset + 12, node.leaf.reserved);
			return;
		}
		for(child in node.children) writeDataEntries(output, child, resourceRva);
	}

	static function writeData(output:Bytes, node:ResourceNode):Void {
		if(node.leaf != null) {
			for(i in 0...node.leaf.data.length) output.set(node.dataOffset + i, node.leaf.data.get(i));
			return;
		}
		for(child in node.children) writeData(output, child);
	}

	static function rvaToFile(rva:Int, sections:Array<PeSection>, path:String):Int {
		for(section in sections) {
			var span = Std.int(Math.max(section.virtualSize, section.rawSize));
			if(rva >= section.virtualAddress && rva < section.virtualAddress + span) {
				var offset = section.rawPointer + rva - section.virtualAddress;
				if(offset < 0 || offset >= section.rawPointer + section.rawSize)
					break;
				return offset;
			}
		}
		Term.error('Cannot read icon resources from $path: resource RVA is not backed by a file section.');
		return 0;
	}

	static function readFile(path:String):Bytes {
		try {
			return sys.io.File.getBytes(path);
		}
		catch(e:Dynamic) {
			Term.error('Could not read $path: $e');
			return Bytes.alloc(0);
		}
	}

	static function align(value:Int, alignment:Int):Int {
		if(alignment <= 1) return value;
		return Std.int(Math.ceil(value / alignment) * alignment);
	}

	static function fixChecksum(bytes:Bytes, checksumOffset:Int):Void {
		writeU32(bytes, checksumOffset, 0);
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
		writeU32(bytes, checksumOffset, Std.int(sum));
	}

	static function writeU16(bytes:Bytes, offset:Int, value:Int):Void {
		bytes.set(offset, value & 0xFF);
		bytes.set(offset + 1, (value >> 8) & 0xFF);
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

	static function u32be(bytes:Bytes, offset:Int):Int {
		return (bytes.get(offset) << 24) | (bytes.get(offset + 1) << 16) | (bytes.get(offset + 2) << 8) | bytes.get(offset + 3);
	}
}
