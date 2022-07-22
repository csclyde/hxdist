class FileUtil {
    public static function createDirectory(path:String) {
		try {
			sys.FileSystem.createDirectory(path);
		}
		catch(e:Dynamic) {
			Term.error("Couldn't create directory "+path+". Maybe it's in use right now? ("+e+")");
		}
	}

    public static function removeDirectory(path:String) {
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
		try {
			sys.io.File.copy(from, to);
		}
		catch(e:Dynamic) {
			Term.error('Can\'t copy $from to $to ($e)');
		}
	}

    public static function zipFolder(zipPath:String, basePath:String) {
		if(zipPath.indexOf(".zip") < 0)
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
