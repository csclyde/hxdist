import haxe.io.Path;

class FileUtil {
	/** Output is cleared recursively; never allow a project or filesystem root. */
	public static function validateOutputDirectory(path:String, projectDir:String):String {
		if(path == null || StringTools.trim(path) == '') throw 'Output directory must not be empty.';
		var output = Path.removeTrailingSlashes(canonicalPath(path));
		var project = Path.removeTrailingSlashes(Path.normalize(sys.FileSystem.fullPath(projectDir)));
		var outputKey = Sys.systemName() == 'Windows' ? output.toLowerCase() : output;
		var projectKey = Sys.systemName() == 'Windows' ? project.toLowerCase() : project;
		if(outputKey == '' || Path.directory(output) == '' || Path.directory(output) == output
			|| outputKey == projectKey || StringTools.startsWith(projectKey, outputKey + '/'))
			throw 'Refusing to clear a filesystem root, project directory, or project ancestor: $output';
		if(sys.FileSystem.exists(output) && !sys.FileSystem.isDirectory(output))
			throw 'Output directory is an existing file: $output';
		return output;
	}

	static function canonicalPath(path:String):String {
		// fullPath requires an existing path on Unix. Resolve the nearest
		// existing ancestor, then append directories that will be created.
		var absolute = Path.normalize(sys.FileSystem.absolutePath(path));
		var suffix:Array<String> = [];
		while(!sys.FileSystem.exists(absolute)) {
			var parent = Path.directory(absolute);
			if(parent == absolute || parent == '') throw 'Cannot resolve output directory: $path';
			suffix.unshift(Path.withoutDirectory(absolute));
			absolute = parent;
		}
		return Path.normalize(Path.join([sys.FileSystem.fullPath(absolute)].concat(suffix)));
	}

	public static function validateProjectName(name:String):Void {
		if(name == null || StringTools.trim(name) == '' || name == '.' || name == '..')
			throw 'Project name must not be empty or a relative path.';
		for(i in 0...name.length)
			if(name.charCodeAt(i) < 32 || '/\\"$`<>:|?*'.indexOf(name.charAt(i)) >= 0)
				throw 'Project name contains a path separator, shell substitution, or invalid filename character.';
	}

    public static function createDirectory(path:String) {
		path = Path.normalize(path);

		try {
			sys.FileSystem.createDirectory(path);
		}
		catch(e:Dynamic) {
			Term.error("Couldn't create directory " + path + ". Maybe it's in use right now? (" + e + ")");
		}
	}

    public static function removeDirectory(path:String) {
		path = Path.normalize(path);

		if(!sys.FileSystem.exists(path)) {
			return;
		}
		else if(!sys.FileSystem.isDirectory(path)) {
			Term.warning("Tried to delete directory (" + path + ") which isn't a directory.");
			return;
		}

		for(e in sys.FileSystem.readDirectory(path)) {
			if(sys.FileSystem.isDirectory(path + "/" + e))
				removeDirectory(path + "/" + e);
			else
				sys.FileSystem.deleteFile(path + "/" + e);
		}

		sys.FileSystem.deleteDirectory(path + "/");
	}

	public static function cleanUpExit() {
		Term.print("Cleaning up...");
	}

    public static function copyFile(from:String, to:String) {
		from = Path.normalize(from);
		to = Path.normalize(to);

		try {
			sys.io.File.copy(from, to);
		}
		catch(e:Dynamic) {
			Term.error('Can\'t copy $from to $to ($e)');
		}
	}

    public static function zipFolder(zipPath:String, basePath:String) {
		zipPath = Path.normalize(zipPath);
		basePath = Path.normalize(basePath);
		basePath = Path.removeTrailingSlashes(basePath);

		if(!StringTools.endsWith(zipPath.toLowerCase(), '.zip'))
			zipPath += ".zip";

		Term.print("Zipping " + basePath + "...");

		// List entries
		var entries : List<haxe.zip.Entry> = new List();
		var pendingDirs = [basePath];
		while(pendingDirs.length>0) {
			var cur = pendingDirs.shift();
			for(fName in sys.FileSystem.readDirectory(cur)) {
				var path = cur+"/"+fName;
				if(sys.FileSystem.isDirectory(path)) {
					pendingDirs.push(path);
					entries.add({
						fileName: path.substr(basePath.length+1) + "/",
						fileSize: 0,
						fileTime: sys.FileSystem.stat(path).ctime,
						data: haxe.io.Bytes.alloc(0),
						dataSize: 0,
						compressed: false,
						crc32: null,
					});
				}
				else {
					var bytes = sys.io.File.getBytes(path);
					entries.add({
						fileName: path.substr(basePath.length+1),
						fileSize: sys.FileSystem.stat(path).size,
						fileTime: sys.FileSystem.stat(path).ctime,
						data: bytes,
						dataSize: bytes.length,
						compressed: false,
						crc32: null,
					});
				}
			}
		}

		// Zip entries
		var out = new haxe.io.BytesOutput();
		for(e in entries) {
			if(e.data.length>0) {
				if(Term.hasOption('verbose')) {
					Term.print(" -> Compressing: " + e.fileName + " (" + e.fileSize + " bytes)");
				}

				e.crc32 = haxe.crypto.Crc32.make(e.data);
				haxe.zip.Tools.compress(e,9);
			}
		}

		var w = new haxe.zip.Writer(out);
		w.write(entries);
		Term.print("Created " + zipPath + " (" + out.length + " bytes)");
		sys.io.File.saveBytes(zipPath, out.getBytes());
	}
}
