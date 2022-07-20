import dn.FileTools;
import dn.FilePath;

class FileUtil {
	public static function initDistDir(d:String) {
		FilePath.SLASH_MODE = OnlySlashes;

		try {
			
			var cwd = StringTools.replace(Sys.getCwd(), "\\", "/");
			var abs = StringTools.replace(sys.FileSystem.absolutePath(d), "\\", "/");
			if(abs.indexOf(cwd) < 0 || abs == cwd)
				Term.error("For security reasons, target folder should be nested inside current folder.");

			FileTools.deleteDirectoryRec(d);
			createDirectory(d);
		}
		catch(e:Dynamic) {
			Term.error("Couldn't initialize dir " + d + ". Maybe it's in use or opened somewhere right now?");
		}
	}

	public static function fromFile(p:String) {
		return FilePath.fromFile(p);
	}

    public static function createTextFile(path:String, content:String) {
		sys.io.File.saveContent(path, content);
	}

    public static function createDirectory(path:String) {
		try {
			sys.FileSystem.createDirectory(path);
		}
		catch(e:Dynamic) {
			Term.error("Couldn't create directory "+path+". Maybe it's in use right now? [ERR:"+e+"]");
		}
	}

    public static function removeDirectory(path:String) {
		if(!sys.FileSystem.exists(path))
			return;

		for(e in sys.FileSystem.readDirectory(path)) {
			if(sys.FileSystem.isDirectory(path+"/"+e))
				removeDirectory(path+"/"+e);
			else
				sys.FileSystem.deleteFile(path+"/"+e);
		}
		sys.FileSystem.deleteDirectory(path+"/");
	}

	public static function cleanUpExit() {
		Term.print("Cleaning up...");
	}

    public static function copy(from:String, to:String) {
		try {
			sys.io.File.copy(from, to);
		}
		catch(e:Dynamic) {
			Term.error("Can't copy "+from+" to "+to+" ("+e+")");
		}
	}

    public static function findFile(distDir:String, f:String) {
		if(sys.FileSystem.exists(distDir + f))
			return distDir + f;

		var paths = [];

		// Prioritize files from the RedistHelper folder
		paths.push(distDir + "dist_files/hl_win/"); // HL 64bits
		paths.push(distDir + "dist_files/");

		// Locate haxe tools
		var haxeTools = ["haxe.exe", "hl.exe", "neko.exe" ];
		for(path in Sys.getEnv("PATH").split(";")) {
			path = cleanUpDirPath(path);
			for(f in haxeTools)
				if(sys.FileSystem.exists(path+f)) {
					paths.push(path);
					break;
				}
		}

		if(paths.length<=0)
			throw "Haxe tools not found ("+haxeTools.join(", ")+") in PATH!";

		for(path in paths)
			if(sys.FileSystem.exists(path+f))
				return path+f;

		throw "File not found: "+f+", lookup paths="+paths.join(", ");
	}

    public static function checkExeInPath(exe:String) {
		var p = new sys.io.Process("where /q "+exe);
		if(p.exitCode()==0)
			return true;
		else
			return false;
	}

    public static function parseHxml(dir:String, f:String): Array<String> {
		var lines = sys.io.File.getContent(dir + f).split('\n');
		var finalLines = [];

		for(line in lines) {
			if(line == '') continue;

			line = StringTools.trim(line.split('#')[0]);

			if(line.indexOf(".hxml") >= 0 && line.indexOf("-cmd") < 0) {
				finalLines = finalLines.concat(parseHxml(dir, line));
			} else {
				finalLines.push(line);
			}
		}

		return finalLines;
	}

    public static function directoryContainsOnly(path:String, allowedExts:Array<String>, ignoredFiles:Array<String>) {
		if(!sys.FileSystem.exists(path))
			return;

		for(e in sys.FileSystem.readDirectory(path)) {
			if(sys.FileSystem.isDirectory(path+"/"+e))
				directoryContainsOnly(path+"/"+e, allowedExts, ignoredFiles);
			else {
				var suspFile = true;
				if(e.indexOf(".")<0)
					suspFile = false; // ignore extension-less files

				for(ext in allowedExts)
					if(e.indexOf("."+ext)>0) {
						suspFile = false;
						break;
					}
				for(f in ignoredFiles)
					if(f==e)
						suspFile = false;
				if(suspFile)
					Term.error("Output folder \""+path+"\" (which will be deleted) seems to contain unexpected files like "+e);
			}
		}
	}

    public static function cleanUpDirPath(path:String) {
		var fp = FilePath.fromDir(path);
		fp.useSlashes();
		return fp.directoryWithSlash;
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
		for(e in entries)
			if(e.data.length>0) {
				if(Term.hasOption('verbose'))
					Term.print(" -> Compressing: "+e.fileName+" ("+e.fileSize+" bytes)");
				else
					Term.print("*");
				e.crc32 = haxe.crypto.Crc32.make(e.data);
				haxe.zip.Tools.compress(e,9);
			}
		var w = new haxe.zip.Writer(out);
		w.write(entries);
		Term.print(" -> Created "+zipPath+" ("+out.length+" bytes)");
		sys.io.File.saveBytes(zipPath, out.getBytes());
	}

	public static function signExecutable(exePath:String) {
		Term.print("Code signing executable...");

		// Check EXE
		if(!sys.FileSystem.exists(exePath))
			Term.error("Cannot sign executable, file not found: " + exePath);

		var fp = FilePath.fromFile(exePath);
		if(fp.extension!="exe") {
			Term.print("  Warning: only supported on Windows executables");
			return false;
		}


		// Check if MS SignTool is installed
		if(!checkExeInPath("signtool.exe"))
			Term.error('You need "signtool.exe" in PATH. You can get it by installing Microsoft Windows SDK (only pick "signing tools").');

		// Get PFX path from either argument or env "CSC_LINK"
		var pfx : Null<String> = null;
		if(Term.hasParam("pfx") && !Term.hasOption("-sign"))
			Term.error('Argument "-pfx" implies to also have "-sign" arg.');

		if(Term.hasOption("sign")) {
			pfx = Term.getParam("pfx");
			if(pfx==null || pfx=="")
				pfx = Sys.getEnv("CSC_LINK");
			if(pfx==null || !sys.FileSystem.exists(pfx))
				Term.error("Certificate file (.pfx) is missing after -pfx argument.");
		}

		Term.print('  Using certificate: $pfx');

		// Get password for env "CSC_KEY_PASSWORD" or by asking the user for it
		var pass = Term.hasOption("-pfx") ? null : Sys.getEnv("CSC_KEY_PASSWORD");
		if(pass==null) {
			Term.print("  Enter PFX password: ");
			pass = Sys.stdin().readLine();
		}
		var result = Sys.command('signtool.exe sign /f "$pfx" /fd SHA256 /t http://timestamp.digicert.com /p "$pass" $exePath');
		if(result!=0)
			Term.error('Code signing failed! (code $result)');

		return true;
	}
	
}