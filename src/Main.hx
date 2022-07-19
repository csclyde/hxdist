import dn.Lib;
import dn.FilePath;
import dn.FileTools;

import FileUtil;

class Main {
	static var distDir = "";
	static var projectDir = "";
	static var projectName = "unknown";
	static var verbose = false;
	static var zipping = false;

	static function main() {
		FilePath.SLASH_MODE = OnlySlashes;

		Term.parseArgs();

		if(Sys.args().length == 0 || Term.hasOption("help")) {
			Term.usage();
		}

		verbose = Term.hasOption("verbose");
		zipping = Term.hasOption("zip");

		// Set CWD to the directory haxelib was called
		distDir = FileUtil.cleanUpDirPath(Sys.getCwd());
		projectDir = FileUtil.cleanUpDirPath(Term.projectDir); // call directory is passed as the last param in haxelibs
		
		if(verbose) {
			Term.print("Dist Dir = " + distDir);
			Term.print("Project Dir = " + projectDir);
		}

		try {
			Sys.setCwd(projectDir);
		}
		catch(e:Dynamic) {
			Term.error("Script wasn't called using: haxelib run hx-dist [...]  (projectDir=" + projectDir+")");
		}

		if(Term.hxmlPaths.length == 0) {
			Term.error("No hxml file provided.");
		}

		// Project name
		projectName = Term.getParam("proj_name");

		if(projectName == null) {
			var split = projectDir.split("/");
			projectName = split[split.length - 2];
		}

		Term.print("Project name: " + projectName);

		// Output folder
		var outputDir = Term.getParam("output_dir");
		if(outputDir == null) 
			outputDir = "dist";

		// Prepare base folder
		FileUtil.initDistDir(outputDir);


		// Parse HXML files given as parameters
		for(hxml in Term.hxmlPaths) {
			Term.print("Parsing " + hxml + "...");
			var content = FileUtil.parseHxml(projectDir, hxml);

			// HL
			if(content.filter((c) -> c.indexOf("-hl ") >= 0).length > 0) {

				Term.print("Building " + hxml + "...");
				compile(hxml);

				// SDL Windows
				if(Term.hasOption('win')) {
					packageHL(hxml, outputDir + "/hl_win/" + projectName, Deps.HL_RUNTIME_FILES_WIN);
					if(zipping)
						FileUtil.zipFolder('${outputDir}/${projectName}_hl_win.zip', outputDir + "/hl_win/");
				}

				// SDL Mac
				if(Term.hasOption("mac")) {
					packageHL(hxml, outputDir + "/hl_mac/" + projectName, Deps.HL_RUNTIME_FILES_MAC);
					if(zipping)
						FileUtil.zipFolder('${outputDir}/${projectName}_hl_mac.zip', outputDir + "/hl_mac/");
				}

				// SDL Linux
				if(Term.hasOption("linux")) {
					packageHL(hxml, outputDir + "/hl_linux/" + projectName, Deps.HL_RUNTIME_FILES_LINUX);
					if(zipping)
						FileUtil.zipFolder('${outputDir}/${projectName}_hl_linux.zip', outputDir + "/hl_linux/");
				}
			}
		}

		FileUtil.cleanUpExit();
		Term.print("Done.");
		Sys.exit(0);
	}

	static function packageHL(hxml:String, hlDir:String, files:Deps.RuntimeFiles) {
		Term.print("Packaging " + hlDir + "...");
		FileUtil.initDistDir(hlDir);
		FileUtil.createDirectory(hlDir);

		// Runtimes
		copyRuntimeFiles(hxml, "HL", hlDir, files);

		// Copy HL bin file
		var out = getHxmlOutput(hxml,"-hl");
		FileUtil.copy(out, hlDir+"/hlboot.dat");
	}


	static function compile(hxmlPath:String) {
		// Compile
		if(Sys.command("haxe", [hxmlPath]) != 0)
			Term.error('Compilation failed!');
	}

	static function copyRuntimeFiles(hxmlPath:String, targetName:String, targetDir:String, runTimeFiles:Deps.RuntimeFiles) {
		if(verbose)
			Term.print("Copying " + targetName + " runtime files to " + targetDir + "... ");

		var exes = [];
		for(r in runTimeFiles.files) {
			if(r.lib==null || hxmlRequiresLib(hxmlPath, r.lib)) {
				try {
					var fileName = r.f;
					var from = FileUtil.findFile(distDir, fileName);

					if(verbose)
						Term.print(" -> " + fileName + (r.lib==null?"" : " [required by -lib " + r.lib+"] (source: " + from+")"));
					var toFile = r.executableFormat!=null ? StringTools.replace(r.executableFormat, "$", projectName) : fileName.indexOf("/")<0 ? fileName : fileName.substr(fileName.lastIndexOf("/")+1);
					var to = targetDir+"/" + toFile;
					if(r.executableFormat!=null && verbose)
						Term.print(" -> Renamed executable to " + toFile);
					FileUtil.copy(from, to);
	
					// List executables
					if(r.executableFormat!=null)
						exes.push(FilePath.fromFile(targetDir+"/" + toFile));
				} catch (e) {
					Term.print(e.message);
				}

			}
		}

		// Set EXEs icon
		if(Term.hasOption("-icon") && runTimeFiles.platform==Windows) // Windows only
			for(exeFp in exes) {
				var i = Term.getParam("icon");
				if(i==null)
					Term.error("Missing icon path");

				var iconFp = FilePath.fromFile(StringTools.replace(i, "\"", ""));

				iconFp.useSlashes();
				exeFp.useSlashes();

				Term.print("Replacing EXE icon...");
				if(!sys.FileSystem.exists(iconFp.full))
					Term.error("Icon file not found: " + iconFp.full);

				if(verbose) {
					Term.print("  exe=" + exeFp.full);
					Term.print("  icon=" + iconFp.full);
				}
				if(runTool('rcedit/rcedit.exe', ['"${exeFp.full}"', '--set-icon "${iconFp.full}" ']) != 0)
					Term.error("rcedit failed!");
			}

		// Sign exe (Windows only)
		if(Term.hasOption("sign") && exes.length>0 && runTimeFiles.platform==Windows)
			for(fp in exes)
				FileUtil.signExecutable(fp.full);
	}


	static function runTool(path:String, args:Array<String>) : Int {
		var toolFp = FilePath.fromFile('$distDir/tools/$path');
		toolFp.useSlashes();
		var cmd = '"${toolFp.full}" ${args.join(" ")}';
		if(verbose)
			Term.print("Executing tool: " + cmd);

		// Use sys.io.Process instead of Sys.command because of quotes ("") bug
		var p = new sys.io.Process(cmd);
		var code = p.exitCode();
		p.close();
		if(verbose && code!=0)
			Term.print('  Failed with error code $code');
		return code;
	}

	static function getHxmlOutput(hxmlPath:String, lookFor:String) : Null<String> {
		if(hxmlPath==null)
			return null;

		if(!sys.FileSystem.exists(hxmlPath))
			Term.error("File not found: " + hxmlPath);

		try {
			var content = FileUtil.parseHxml(projectDir, hxmlPath);
			for(line in content) {
				if(line.indexOf(lookFor)>=0)
					return StringTools.trim(line.split(lookFor)[1]);
			}
		} catch(e:Dynamic) {
			Term.error("Could not read " + hxmlPath+" (" + e+")");
		}
		Term.error("No " + lookFor+" output in " + hxmlPath);
		return null;
	}

	static function hxmlRequiresLib(hxmlPath:String, libId:String) : Bool {
		if(hxmlPath==null)
			return false;

		if(!sys.FileSystem.exists(hxmlPath))
			Term.error("File not found: " + hxmlPath);

		try {
			var fi = sys.io.File.read(hxmlPath, false);
			var content = fi.readAll().toString();
			if(content.indexOf("-lib " + libId)>=0)
				return true;
			for(line in content.split('\n'))
				if(line.indexOf(".hxml")>=0)
					return hxmlRequiresLib(line, libId);
		} catch(e:Dynamic) {
			Term.error("Could not read " + hxmlPath+" (" + e+")");
		}
		return false;
	}	
}
