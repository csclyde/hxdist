import haxe.io.Bytes;
import haxe.io.Path;
import sys.FileSystem;
import HashLinkBytecode.HashLinkNative;

typedef ResolvedNativeFile = {
	var source:String;
	var destination:String;
	var reason:String;
}

typedef NativeConfig = {
	var searchPaths:Array<String>;
	var include:Array<String>;
	var exclude:Array<String>;
}

/** Discovers the native runtime closure for a HashLink application. */
class NativeDependencies {
	static var deepSearchRoots:Map<String, Bool> = new Map<String, Bool>();

	public static function resolve(bootPath:String, projectDir:String, projectName:String, platform:String):Array<ResolvedNativeFile> {
		var config = loadConfig(projectDir);
		var roots = buildSearchRoots(projectDir, config.searchPaths);
		var files:Array<ResolvedNativeFile> = [];
		var byDestination = new Map<String, ResolvedNativeFile>();
		var queued = new Map<String, Bool>();
		var inspected = new Map<String, Bool>();

		// These are the VM and launcher files. Their native dependencies are
		// inspected as well, so they do not need a second handwritten list.
		for(name in runtimeNames(platform)) {
			var source = locate(name, roots, null);
			if(source == null)
					Term.error('Could not find required HashLink runtime file "$name". Searched the active development system.');
			var destination = name;
			if(name == 'hl' && platform == 'Linux') destination = '$projectName.x64';
			if(name == 'hl' && platform == 'Mac') destination = projectName;
			if(name == 'hl.exe' && platform == 'Windows') destination = '$projectName.exe';
			addFile(source, destination, 'HashLink runtime', files, byDestination, queued);
		}

		var nativeNames: Array<HashLinkNative>;
		try {
			nativeNames = HashLinkBytecode.natives(bootPath);
		}
		catch(e:Dynamic) {
			Term.error('Could not inspect HashLink bytecode "$bootPath": $e');
			return files;
		}

		for(native in nativeNames)
			addHdll(native.name, native.optional, roots, files, byDestination, queued);

		// Explicit inclusions are for runtime-loaded plugins and project-specific
		// native files that cannot appear in the static HL native table.
		for(include in config.include) {
			var source = include;
			if(!Path.isAbsolute(source)) source = Path.normalize(projectDir + '/' + source);
			if(!FileSystem.exists(source) || FileSystem.isDirectory(source))
				Term.error('Configured native file does not exist: $source');
			addFile(source, Path.withoutDirectory(source), 'hxdist.json include', files, byDestination, queued);
		}

		var queueIndex = 0;
		while(queueIndex < files.length) {
			var file = files[queueIndex++];
			var sourceKey = key(file.source);
			if(inspected.exists(sourceKey)) continue;
			inspected.set(sourceKey, true);

			var imports = inspectBinary(file.source, platform);
			if(imports == null) continue;
			for(importName in imports) {
				if(isExcluded(importName, config.exclude)) continue;
				if(isBuiltin(importName, platform)) continue;

				var localDir = Path.directory(file.source);
				var dependency = locate(importName, roots, localDir);
				if(dependency == null) {
					if(isSystemDependency(importName, platform)) {
						Term.warning('Leaving system dependency outside package: $importName (required by ${file.destination})');
						continue;
					}
					Term.error('Could not resolve native dependency "$importName" required by ${file.destination}. Add it to hxdist.json searchPaths/include.');
				}
				addFile(dependency, importName, 'native dependency of ${file.destination}', files, byDestination, queued);
			}
		}

		return files;
	}

	static function addHdll(name:String, optional:Bool, roots:Array<String>, files:Array<ResolvedNativeFile>, byDestination:Map<String, ResolvedNativeFile>, queued:Map<String, Bool>):Void {
		var candidates = [];
		if(StringTools.endsWith(name, '.hdll')) {
			candidates.push(name);
		} else {
			candidates.push(name + '64.hdll');
			candidates.push(name + '.hdll');
		}
		var source:String = null;
		for(candidate in candidates) {
			source = locate(candidate, roots, null);
			if(source != null) break;
		}
		if(source == null) {
			if(optional) {
				Term.warning('Optional HashLink library "$name" was not found; continuing.');
				return;
			}
			Term.error('Could not find required HashLink library "$name". Searched the active development system.');
		}
		addFile(source, Path.withoutDirectory(source), 'HashLink native library $name', files, byDestination, queued);
	}

	static function addFile(source:String, destination:String, reason:String, files:Array<ResolvedNativeFile>, byDestination:Map<String, ResolvedNativeFile>, queued:Map<String, Bool>):Void {
		source = Path.normalize(FileSystem.fullPath(source));
		destination = Path.withoutDirectory(StringTools.replace(destination, '\\', '/'));
		var destinationKey = key(destination);
		var existing = byDestination.get(destinationKey);
		if(existing != null) {
			if(key(existing.source) != key(source))
				Term.error('Two native files would be written as "$destination": ${existing.source} and $source');
			return;
		}
		var file:ResolvedNativeFile = {source: source, destination: destination, reason: reason};
		byDestination.set(destinationKey, file);
		files.push(file);
		queued.set(key(source), true);
	}

	static function loadConfig(projectDir:String):NativeConfig {
		var result:NativeConfig = {searchPaths: [], include: [], exclude: []};
		var path = Path.normalize(projectDir + '/hxdist.json');
		if(!FileSystem.exists(path)) return result;
		var value:Dynamic;
		try {
			value = haxe.Json.parse(sys.io.File.getContent(path));
		}
		catch(e:Dynamic) {
			Term.error('Could not parse $path: $e');
			return result;
		}
		result.searchPaths = strings(value.searchPaths);
		result.include = strings(value.include);
		result.exclude = strings(value.exclude);
		return result;
	}

	static function strings(value:Dynamic):Array<String> {
		var result:Array<String> = [];
		if(value == null || !Std.isOfType(value, Array)) return result;
		for(item in (cast value:Array<Dynamic>))
			if(Std.isOfType(item, String)) result.push(cast item);
		return result;
	}

	static function buildSearchRoots(projectDir:String, configured:Array<String>):Array<String> {
		var result:Array<String> = [];
		var seen = new Map<String, Bool>();
		deepSearchRoots = new Map<String, Bool>();
		function add(path:String, deep:Bool = false) {
			if(path == null || path == '') return;
			if(!Path.isAbsolute(path)) path = Path.normalize(projectDir + '/' + path);
			if(!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return;
			path = Path.normalize(FileSystem.fullPath(path));
			if(!seen.exists(key(path))) {
				seen.set(key(path), true);
				result.push(path);
			}
			if(deep) deepSearchRoots.set(key(path), true);
		}

		for(path in configured) add(path, true);
		for(path in environmentPaths('HL_PATH')) add(path, true);
		for(path in environmentPaths('HAXE_STD_PATH')) add(path, true);
		for(path in environmentPaths('PATH')) add(path);

		var haxelibRoot = commandFirstLine('haxelib', ['config']);
		if(haxelibRoot != null) add(haxelibRoot, true);
		add(projectDir, true);
		return result;
	}

	static function environmentPaths(name:String):Array<String> {
		var value = Sys.getEnv(name);
		if(value == null || value == '') return [];
		return value.split(Sys.systemName() == 'Windows' ? ';' : ':');
	}

	static function runtimeNames(platform:String):Array<String> {
		return switch(platform) {
			case 'Windows': ['hl.exe', 'libhl.dll'];
			case 'Mac': ['hl', 'libhl.dylib'];
			default: ['hl', 'libhl.so'];
		}
	}

	static function locate(name:String, roots:Array<String>, localDir:String):String {
		name = StringTools.replace(name, '\\', '/');
		if(Path.isAbsolute(name) && FileSystem.exists(name) && !FileSystem.isDirectory(name)) return name;
		if(localDir != null) {
			var local = Path.normalize(localDir + '/' + Path.withoutDirectory(name));
			if(FileSystem.exists(local) && !FileSystem.isDirectory(local)) return local;
		}
		for(root in roots) {
			var direct = Path.normalize(root + '/' + Path.withoutDirectory(name));
			if(FileSystem.exists(direct) && !FileSystem.isDirectory(direct)) return direct;
		}
		for(root in roots) {
			if(!deepSearchRoots.exists(key(root))) continue;
			var found = locateRecursive(root, Path.withoutDirectory(name), 5, new Map<String, Bool>());
			if(found != null) return found;
		}
		return null;
	}

	static function locateRecursive(root:String, name:String, depth:Int, visited:Map<String, Bool>):String {
		if(depth < 0 || !FileSystem.exists(root) || !FileSystem.isDirectory(root)) return null;
		var rootKey = key(root);
		if(visited.exists(rootKey)) return null;
		visited.set(rootKey, true);
		var entries:Array<String>;
		try {
			entries = FileSystem.readDirectory(root);
		}
		catch(e:Dynamic) {
			return null;
		}
		for(entry in entries) {
			var path = Path.normalize(root + '/' + entry);
			if(!FileSystem.exists(path)) continue;
			if(!FileSystem.isDirectory(path) && key(entry) == key(name)) return path;
		}
		if(depth == 0) return null;
		for(entry in entries) {
			var path = Path.normalize(root + '/' + entry);
			if(FileSystem.exists(path) && FileSystem.isDirectory(path)) {
				var found = locateRecursive(path, name, depth - 1, visited);
				if(found != null) return found;
			}
		}
		return null;
	}

	static function commandFirstLine(command:String, args:Array<String>):String {
		try {
			var p = new sys.io.Process(command, args);
			var output = p.stdout.readAll().toString();
			var code = p.exitCode();
			p.close();
			if(code != 0) return null;
			for(line in output.split('\n')) {
				line = StringTools.trim(line);
				if(line != '') return line;
			}
		}
		catch(e:Dynamic) {}
		return null;
	}

	static function inspectBinary(path:String, platform:String):Null<Array<String>> {
		var bytes = sys.io.File.getBytes(path);
		if(bytes.length >= 2 && bytes.get(0) == 0x4D && bytes.get(1) == 0x5A)
			return inspectPE(bytes);
		if(bytes.length >= 4 && bytes.get(0) == 0x7F && bytes.get(1) == 0x45 && bytes.get(2) == 0x4C && bytes.get(3) == 0x46)
			return inspectELF(bytes);
		if(platform == 'Mac') return inspectMachO(path);
		return null;
	}

	static function inspectPE(b:Bytes):Array<String> {
		if(b.length < 0x40) return [];
		var pe = u32(b, 0x3C);
		if(pe < 0 || pe + 24 > b.length || u32(b, pe) != 0x00004550) return [];
		var coff = pe + 4;
		var sections = u16(b, coff + 2);
		var optionalSize = u16(b, coff + 16);
		var optional = coff + 20;
		if(optional + optionalSize > b.length) return [];
		var magic = u16(b, optional);
		var directory = magic == 0x20B ? optional + 112 : optional + 96;
		var numberOfDirectoriesOffset = magic == 0x20B ? optional + 108 : optional + 92;
		if(directory + 16 > b.length || numberOfDirectoriesOffset + 4 > b.length) return [];
		var numberOfDirectories = u32(b, numberOfDirectoriesOffset);
		var importRva = numberOfDirectories > 1 ? u32(b, directory + 8) : 0;
		var delayRva = numberOfDirectories > 13 ? u32(b, directory + 13 * 8) : 0;
		var sectionStart = optional + optionalSize;
		var result:Array<String> = [];
		if(importRva != 0) result = result.concat(readPEImports(b, importRva, sectionStart, sections, 20, 12));
		if(delayRva != 0) result = result.concat(readPEImports(b, delayRva, sectionStart, sections, 32, 4));
		return unique(result);
	}

	static function readPEImports(b:Bytes, rva:Int, sectionStart:Int, sectionCount:Int, stride:Int, nameField:Int):Array<String> {
		var result:Array<String> = [];
		var offset = peRvaOffset(b, rva, sectionStart, sectionCount);
		if(offset < 0) return result;
		for(i in 0...4096) {
			var at = offset + i * stride;
			if(at + stride > b.length) break;
			var nameRva = u32(b, at + nameField);
			if(nameRva == 0) break;
			var nameOffset = peRvaOffset(b, nameRva, sectionStart, sectionCount);
			if(nameOffset < 0) break;
			var name = cstring(b, nameOffset);
			if(name != '') result.push(name);
		}
		return result;
	}

	static function peRvaOffset(b:Bytes, rva:Int, sectionStart:Int, count:Int):Int {
		for(i in 0...count) {
			var at = sectionStart + i * 40;
			if(at + 40 > b.length) return -1;
			var virtualSize = u32(b, at + 8);
			var virtualAddress = u32(b, at + 12);
			var rawSize = u32(b, at + 16);
			var rawOffset = u32(b, at + 20);
			var size = virtualSize > rawSize ? virtualSize : rawSize;
			if(rva >= virtualAddress && rva < virtualAddress + size)
				return rawOffset + (rva - virtualAddress);
		}
		return -1;
	}

	static function inspectELF(b:Bytes):Array<String> {
		if(b.length < 64) return [];
		var is64 = b.get(4) == 2;
		var little = b.get(5) == 1;
		if(!little) return [];
		var phoff = is64 ? u32(b, 32) : u32(b, 28);
		var phentsize = u16(b, is64 ? 54 : 42);
		var phnum = u16(b, is64 ? 56 : 44);
		var dynamicOffset = -1;
		var loads:Array<{v:Int, o:Int, size:Int}> = [];
		for(i in 0...phnum) {
			var at = phoff + i * phentsize;
			if(at + phentsize > b.length) break;
			var type = u32(b, at);
			var offset = is64 ? u32(b, at + 8) : u32(b, at + 4);
			var vaddr = is64 ? u32(b, at + 16) : u32(b, at + 8);
			var filesz = is64 ? u32(b, at + 32) : u32(b, at + 16);
			var memsz = is64 ? u32(b, at + 40) : u32(b, at + 20);
			if(type == 2) dynamicOffset = offset;
			if(type == 1) loads.push({v:vaddr, o:offset, size:memsz > filesz ? memsz : filesz});
		}
		if(dynamicOffset < 0) return [];
		var strtab = -1;
		var needed:Array<Int> = [];
		var entrySize = is64 ? 16 : 8;
		for(i in 0...65536) {
			var at = dynamicOffset + i * entrySize;
			if(at + entrySize > b.length) break;
			var tag = u32(b, at);
			var value = is64 ? u32(b, at + 8) : u32(b, at + 4);
			if(tag == 0) break;
			if(tag == 1) needed.push(value);
			if(tag == 5) strtab = value;
		}
		if(strtab < 0) return [];
		var strOffset = -1;
		for(load in loads) {
			if(strtab >= load.v && strtab < load.v + load.size) {
				strOffset = load.o + strtab - load.v;
				break;
			}
		}
		if(strOffset < 0) return [];
		var result:Array<String> = [];
		for(index in needed) {
			var name = cstring(b, strOffset + index);
			if(name != '') result.push(name);
		}
		return unique(result);
	}

	static function inspectMachO(path:String):Null<Array<String>> {
		var tool = findOnPath('otool');
		if(tool == null) {
			Term.warning('Cannot inspect macOS native dependencies for $path because otool was not found.');
			return null;
		}
		try {
			var p = new sys.io.Process(tool, ['-L', path]);
			var output = p.stdout.readAll().toString();
			var code = p.exitCode();
			p.close();
			if(code != 0) return null;
			var result:Array<String> = [];
			var first = true;
			for(line in output.split('\n')) {
				line = StringTools.trim(line);
				if(first) {
					first = false;
					continue;
				}
				var marker = line.indexOf(' (');
				if(marker <= 0) continue;
				result.push(line.substr(0, marker));
			}
			return unique(result);
		}
		catch(e:Dynamic) return null;
	}

	static function findOnPath(name:String):String {
		for(dir in environmentPaths('PATH')) {
			var candidate = Path.normalize(dir + '/' + name + (Sys.systemName() == 'Windows' ? '.exe' : ''));
			if(FileSystem.exists(candidate) && !FileSystem.isDirectory(candidate)) return candidate;
		}
		return null;
	}

	static function isExcluded(name:String, excludes:Array<String>):Bool {
		for(exclude in excludes) if(key(exclude) == key(name)) return true;
		return false;
	}

	static function isBuiltin(name:String, platform:String):Bool {
		var lower = name.toLowerCase();
		if(platform == 'Windows') {
			return StringTools.startsWith(lower, 'api-ms-win-') || StringTools.startsWith(lower, 'ext-ms-win-') || lower == 'kernel32.dll' || lower == 'user32.dll' || lower == 'gdi32.dll' || lower == 'advapi32.dll' || lower == 'shell32.dll' || lower == 'ole32.dll' || lower == 'oleaut32.dll' || lower == 'ws2_32.dll' || lower == 'winmm.dll' || lower == 'version.dll';
		}
		return false;
	}

	static function isSystemDependency(name:String, platform:String):Bool {
		var lower = name.toLowerCase();
		if(platform == 'Mac') return StringTools.startsWith(lower, '/system/') || StringTools.startsWith(lower, '/usr/lib/') || StringTools.startsWith(lower, 'libsystem') || StringTools.startsWith(lower, '@rpath/libsystem');
		if(platform == 'Linux') return StringTools.startsWith(lower, 'linux-vdso') || StringTools.startsWith(lower, 'libc.so') || StringTools.startsWith(lower, 'libm.so') || StringTools.startsWith(lower, 'libpthread.so') || StringTools.startsWith(lower, 'librt.so') || StringTools.startsWith(lower, 'libdl.so') || StringTools.startsWith(lower, 'libgcc_s.so') || StringTools.startsWith(lower, 'ld-linux') || StringTools.startsWith(lower, 'libresolv.so');
		return isBuiltin(name, platform);
	}

	static function unique(values:Array<String>):Array<String> {
		var result:Array<String> = [];
		var seen = new Map<String, Bool>();
		for(value in values) if(!seen.exists(key(value))) {
			seen.set(key(value), true);
			result.push(value);
		}
		return result;
	}

	static function key(value:String):String return Sys.systemName() == 'Windows' ? value.toLowerCase() : value;

	static function u16(b:Bytes, at:Int):Int return b.get(at) | (b.get(at + 1) << 8);
	static function u32(b:Bytes, at:Int):Int return b.get(at) | (b.get(at + 1) << 8) | (b.get(at + 2) << 16) | (b.get(at + 3) << 24);

	static function cstring(b:Bytes, at:Int):String {
		if(at < 0 || at >= b.length) return '';
		var end = at;
		while(end < b.length && b.get(end) != 0) end++;
		return b.sub(at, end - at).toString();
	}
}
