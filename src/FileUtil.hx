
class FileUtil {
    public static function createTextFile(path:String, content:String) {
		sys.io.File.saveContent(path, content);
	}

    public static function createDirectory(path:String) {
		try {
			sys.FileSystem.createDirectory(path);
		}
		catch(e:Dynamic) {
			Terminal.error("Couldn't create directory "+path+". Maybe it's in use right now? [ERR:"+e+"]");
		}
	}

    public static function removeDirectory(path:String) {
		if( !sys.FileSystem.exists(path) )
			return;

		for( e in sys.FileSystem.readDirectory(path) ) {
			if( sys.FileSystem.isDirectory(path+"/"+e) )
				removeDirectory(path+"/"+e);
			else
				sys.FileSystem.deleteFile(path+"/"+e);
		}
		sys.FileSystem.deleteDirectory(path+"/");
	}

    public static function copy(from:String, to:String) {
		try {
			sys.io.File.copy(from, to);
		}
		catch(e:Dynamic) {
			Terminal.error("Can't copy "+from+" to "+to+" ("+e+")");
		}
	}

    public static function findFile(f:String, useHl32bits:Bool) {
		if( sys.FileSystem.exists(redistHelperDir+f) )
			return redistHelperDir+f;

		var paths = [];

		// Prioritize files from the RedistHelper folder
		if( useHl32bits )
			paths.push(redistHelperDir+"redistFiles/hl32/");  // HL 32bits in priority over 64bits
		paths.push(redistHelperDir+"redistFiles/hl64/"); // HL 64bits
		paths.push(redistHelperDir+"redistFiles/");

		// Locate haxe tools
		var haxeTools = ["haxe.exe", "hl.exe", "neko.exe" ];
		for(path in Sys.getEnv("PATH").split(";")) {
			path = cleanUpDirPath(path);
			for(f in haxeTools)
				if( sys.FileSystem.exists(path+f) ) {
					paths.push(path);
					break;
				}
		}

		if( paths.length<=0 )
			throw "Haxe tools not found ("+haxeTools.join(", ")+") in PATH!";

		for(path in paths)
			if( sys.FileSystem.exists(path+f) )
				return path+f;

		throw "File not found: "+f+", lookup paths="+paths.join(", ");
	}

    public static function checkExeInPath(exe:String) {
		var p = new sys.io.Process("where /q "+exe);
		if( p.exitCode()==0 )
			return true;
		else
			return false;
	}

    public static function getFullHxml(f:String) {
		var lines = sys.io.File.read(f, false).readAll().toString().split(NEW_LINE);
		var i = 0;
		while( i<lines.length ) {

			// trims the comment content from the line.
			var commentHash = lines[i].indexOf("#");
			if( commentHash >= 0 )
				lines[i] = lines[i].substr(0, commentHash);

			if( lines[i].indexOf(".hxml")>=0 && lines[i].indexOf("-cmd")<0 )
				lines[i] = getFullHxml(lines[i]);
			i++;
		}

		return lines.join(NEW_LINE);
	}

    public static function directoryContainsOnly(path:String, allowedExts:Array<String>, ignoredFiles:Array<String>) {
		if( !sys.FileSystem.exists(path) )
			return;

		for( e in sys.FileSystem.readDirectory(path) ) {
			if( sys.FileSystem.isDirectory(path+"/"+e) )
				directoryContainsOnly(path+"/"+e, allowedExts, ignoredFiles);
			else {
				var suspFile = true;
				if( e.indexOf(".")<0 )
					suspFile = false; // ignore extension-less files

				for(ext in allowedExts)
					if( e.indexOf("."+ext)>0 ) {
						suspFile = false;
						break;
					}
				for(f in ignoredFiles)
					if( f==e )
						suspFile = false;
				if( suspFile )
					error("Output folder \""+path+"\" (which will be deleted) seems to contain unexpected files like "+e);
			}
		}
	}

    public static function initRedistDir(d:String, extraFiles:Array<ExtraCopiedFile>) {
		if( verbose )
			Lib.println("Initializing folder: "+d+"...");
		try {
			// List all extra files, including folders content
			var allExtraFiles = [];
			for(f in extraFiles)
				if( !f.isDir )
					allExtraFiles.push(f.rename!=null ? f.rename : f.source.fileWithExt);
				else {
					var all = FileTools.listAllFilesRec(f.source.full);
					for(f in all.files)
						allExtraFiles.push( FilePath.extractFileWithExt(f) );
				}


			var cwd = StringTools.replace( Sys.getCwd(), "\\", "/" );
			var abs = StringTools.replace( sys.FileSystem.absolutePath(d), "\\", "/" );
			if( abs.indexOf(cwd)<0 || abs==cwd )
				error("For security reasons, target folder should be nested inside current folder.");
			// avoid deleting unexpected files
			directoryContainsOnly(
				d,
				["exe","dat","dll","hdll","ndll","js","swf","html","dylib","zip","lib","bin","bat","pak"],
				allExtraFiles
			);
			FileTools.deleteDirectoryRec(d);
			createDirectory(d);
		}
		catch(e:Dynamic) {
			error("Couldn't initialize dir "+d+". Maybe it's in use or opened somewhere right now?");
		}
	}

    public static function cleanUpDirPath(path:String) {
		var fp = FilePath.fromDir(path);
		fp.useSlashes();
		return fp.directoryWithSlash;
	}

    public static function copyExtraFilesIn(extraFiles:Array<ExtraCopiedFile>, targetPath:String) {
		if( extraFiles.length==0 )
			return;

		Sys.println("Copying extra files to "+targetPath+"...");

		// Ignored files/dirs
		var ignores = getIgnoredElements();
		ignores.names.push(".tmp");
		ignores.names.push(".git");
		ignores.names.push(".svn");
		Sys.println("  Ignoring: names="+ignores.names+" extensions="+ignores.exts);

		// Copy extra files/dirs
		for(f in extraFiles) {
			if( f.isDir ) {
				// Copy a directory structure
				if( verbose )
					Lib.println(" -> DIRECTORY: "+projectDir+f.source.full+"  =>  "+targetPath);
				FileTools.copyDirectoryRec(f.source.full, targetPath, ignores.names, ignores.exts);

				// Rename
				if( f.rename!=null ) {
					var arr = f.source.getDirectoryArray();
					var folderName = arr[arr.length-1];
					if( verbose )
						Lib.println("   -> renaming "+targetPath+"/"+folderName+" to: "+targetPath+"/"+f.rename);
					sys.FileSystem.rename(targetPath+"/"+folderName, targetPath+"/"+f.rename);
				}
			}
			else {
				// Copy a file
				var to = f.source.fileWithExt;
				if( f.rename!=null )
					to = f.rename;
				if( verbose )
					Lib.println(" -> FILE: "+projectDir+f.source.full+"  =>  "+targetPath+"/"+to);
				copy(projectDir+f.source.full, targetPath+"/"+to);
			}
		}
	}

    public static function zipFolder(zipPath:String, basePath:String) {
		if( zipPath.indexOf(".zip")<0 )
			zipPath+=".zip";

		Lib.println("Zipping "+basePath+"...");
		if( !verbose )
			Lib.print(" -> ");

		// List entries
		var entries : List<haxe.zip.Entry> = new List();
		var pendingDirs = [basePath];
		while( pendingDirs.length>0 ) {
			var cur = pendingDirs.shift();
			for( fName in sys.FileSystem.readDirectory(cur) ) {
				var path = cur+"/"+fName;
				if( sys.FileSystem.isDirectory(path) ) {
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
		for(e in entries)
			if( e.data.length>0 ) {
				if( verbose )
					Sys.println(" -> Compressing: "+e.fileName+" ("+e.fileSize+" bytes)");
				else
					Sys.print("*");
				e.crc32 = haxe.crypto.Crc32.make(e.data);
				haxe.zip.Tools.compress(e,9);
			}
		var w = new haxe.zip.Writer(out);
		w.write(entries);
		Lib.println(" -> Created "+zipPath+" ("+out.length+" bytes)");
		sys.io.File.saveBytes(zipPath, out.getBytes());
	}
	
}