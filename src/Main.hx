import dn.Lib;
import dn.FilePath;
import dn.FileTools;

import FileUtil;



class Main {

	static var PAK_BUILDER_BIN = "pakBuilder.hl";
	static var PAK_BUILDER_OUT = "redistTmp";

	static var SINGLE_PARAMETERS = [
		"-zip" => true,
		"-sign" => true,
		"-pak" => true,
		"-h" => true,
		"--help" => true,
		"-z" => true,
		"-v" => true,
		"--verbose" => true,
		"-hl32" => true,
		"-mac" => true,
		"-linux" => true,
	];

	static var NEW_LINE = "\n";

	static var redistHelperDir = "";
	static var projectDir = "";
	static var projectName = "unknown";
	static var verbose = false;


	static function main() {
		haxe.Log.trace = function(m, ?pos) {
			if ( pos != null && pos.customParams == null )
				pos.customParams = ["debug"];

			Lib.println(Std.string(m));
		}
		FilePath.SLASH_MODE = OnlySlashes;

		if( Sys.args().length==0 )
			usage();

		Sys.println("");

		// Misc parameters
		if( hasParameter("-h") || hasParameter("--help") )
			usage();
		verbose = hasParameter("-v") || hasParameter("--verbose");
		var zipping = hasParameter("-zip") || hasParameter("-z");
		var isolatedParams = getIsolatedParameters();

		// Set CWD to the directory haxelib was called
		redistHelperDir = cleanUpDirPath( Sys.getCwd() );
		projectDir = cleanUpDirPath( isolatedParams.pop() ); // call directory is passed as the last param in haxelibs
		if( verbose ) {
			Sys.println("RedistHelperDir="+redistHelperDir);
			Sys.println("ProjectDir="+projectDir);
		}
		try {
			Sys.setCwd(projectDir);
		}
		catch(e:Dynamic) {
			error("Script wasn't called using: haxelib run redistHelper [...]  (projectDir="+projectDir+")");
		}

		// List HXMLs and extra files
		var hxmlPaths = [];
		var extraFiles : Array<ExtraCopiedFile> = [];
		for(p in isolatedParams)
			if( p.indexOf(".hxml")>=0 )
				hxmlPaths.push(p);
			else {
				// Found an isolated extra file to copy
				var renameParts = p.split("@");
				var path = renameParts[0];
				if( !sys.FileSystem.exists(path) )
					error("File not found: "+path);

				var isDir = sys.FileSystem.isDirectory(path);
				var originalFile = isDir ? FilePath.fromDir(path) : FilePath.fromFile(path);
				if( renameParts.length==1 )
					extraFiles.push({ source:originalFile, rename:null, isDir:isDir });
				else
					extraFiles.push({ source:originalFile, rename:renameParts[1], isDir:isDir });
			}
		if( verbose ) {
			Sys.println("ExtraFiles listing:");
			for(e in extraFiles) {
				Sys.println( " -> "+e.source.full
					+ ( e.rename!=null ? " >> "+e.rename : "" )
					+ ( e.isDir ? " [DIRECTORY]" : "" )
				);
			}
		}
		if( hxmlPaths.length==0 ) {
			usage();
			// // Search for HXML in project folder if no parameter was given
			// for( f in sys.FileSystem.readDirectory(projectDir) )
			// 	if( !sys.FileSystem.isDirectory(f) && f.indexOf(".hxml")>=0 )
			// 		hxmlPaths.push(f);

			// if( hxmlPaths.length==0 )
			// 	error("No HXML found in current folder.");
			// else
			// 	Lib.println("Discovered "+hxmlPaths.length+" potential HXML file(s): "+hxmlPaths.join(", "));
		}

		// Project name
		projectName = getParameter("-p");
		if( projectName==null ) {
			var split = projectDir.split("/");
			projectName = split[split.length-2];
		}
		Lib.println("Project name: "+projectName);

		// Output folder
		var baseRedistDir = getParameter("-o");
		if( baseRedistDir==null )
			baseRedistDir = "redist";
		if( baseRedistDir.indexOf("$")>=0 )
			error("The \"$\" in the \"-o\" parameter is deprecated. RedistHelper now exports each redistribuable to a separate folder by default.");

		// Prepare base folder
		initRedistDir(baseRedistDir, extraFiles);


		// Parse HXML files given as parameters
		for(hxml in hxmlPaths) {
			Sys.println("Parsing "+hxml+"...");
			var content = getFullHxml( hxml );

			// HL
			if( content.indexOf("-hl ")>=0 ) {
				// Build
				var directX = content.indexOf("hldx")>0;

				Lib.println("Building "+hxml+"...");
				compile(hxml);

				function makeHl(hlDir:String, files:RuntimeFiles, use32bits:Bool) {
					Lib.println("Packaging "+hlDir+"...");
					initRedistDir(hlDir, extraFiles);

					// Create folder
					createDirectory(hlDir);

					// Runtimes
					copyRuntimeFiles(hxml, "HL", hlDir, files, use32bits);

					// Copy HL bin file
					var out = getHxmlOutput(hxml,"-hl");
					copy(out, hlDir+"/hlboot.dat");

					copyExtraFilesIn(extraFiles, hlDir);
				}

				// Package HL
				if( directX ) {
					// DirectX 64bits
					makeHl(baseRedistDir+"/directx/"+projectName, HL_RUNTIME_FILES_WIN, false);
					if( zipping )
						zipFolder( '$baseRedistDir/${projectName}_directx.zip', baseRedistDir+"/directx");

					// DirectX 32bits
					if( hasParameter("-hl32") ) {
						makeHl(baseRedistDir+"/directx32/"+projectName, HL_RUNTIME_FILES_WIN, true); // directX 32 bits
						if( zipping )
							zipFolder( '$baseRedistDir/${projectName}_directx32.zip', baseRedistDir+"/directx32");
					}
				}
				else {
					// SDL Windows 64bits
					makeHl(baseRedistDir+"/opengl_win/"+projectName, HL_RUNTIME_FILES_WIN, false);
					if( zipping )
						zipFolder( '$baseRedistDir/${projectName}_opengl_win.zip', baseRedistDir+"/opengl_win/");

					// SDL Windows 32bits
					if( hasParameter("-hl32") ) {
						makeHl(baseRedistDir+"/opengl_win32/"+projectName, HL_RUNTIME_FILES_WIN, true);
						if( zipping )
							zipFolder( '$baseRedistDir/${projectName}_opengl_win32.zip', baseRedistDir+"/opengl_win32/");
					}

					// SDL Mac
					// if( hasParameter("-mac") ) {
					// 	makeHl(baseRedistDir+"/opengl_mac/"+projectName, HL_RUNTIME_FILES_MAC, false);
					// 	if( zipping )
					// 		zipFolder( '$baseRedistDir/${projectName}_opengl_mac.zip', baseRedistDir+"/opengl_mac/");
					// }

					// SDL Linux
					if( hasParameter("-linux") ) {
						makeHl(baseRedistDir+"/opengl_linux/"+projectName, HL_RUNTIME_FILES_LINUX, false);
						if( zipping )
							zipFolder( '$baseRedistDir/${projectName}_opengl_linux.zip', baseRedistDir+"/opengl_linux/");
					}
				}
			}

			// JS
			if( content.indexOf("-js ")>=0 ) {
				// Build
				var jsDir = baseRedistDir+"/js";
				initRedistDir(jsDir, extraFiles);

				Lib.println("Building "+hxml+"...");
				compile(hxml);

				Lib.println("Packaging "+jsDir+"...");
				var out = getHxmlOutput(hxml,"-js");
				copy(out, jsDir+"/client.js");

				// Create HTML
				Lib.println("Creating HTML...");
				var fi = sys.io.File.read(redistHelperDir+"redistFiles/webgl.html");
				var html = "";
				while( !fi.eof() )
				try { html += fi.readLine()+NEW_LINE; } catch(e:haxe.io.Eof) {}
				html = StringTools.replace(html, "%project%", projectName);
				html = StringTools.replace(html, "%js%", "client.js");
				var fo = sys.io.File.write(jsDir+"/index.html", false);
				fo.writeString(html);
				fo.close();

				copyExtraFilesIn(extraFiles, jsDir);
				if( zipping )
					zipFolder( baseRedistDir+"/js.zip", jsDir);
			}

			// Neko
			if( content.indexOf("-neko ")>=0 ) {
				var nekoDir = baseRedistDir+"/neko";
				initRedistDir(nekoDir, extraFiles);

				Lib.println("Building "+hxml+"...");
				compile(hxml);

				Lib.println("Creating executable...");
				var out = FilePath.fromFile( getHxmlOutput(hxml,"-neko") );
				Sys.command("nekotools", ["boot",out.full]);
				out.extension = "exe";

				Lib.println("Packaging "+nekoDir+"...");
				copy(out.full, nekoDir+"/"+projectName+".exe");
				if( hasParameter("-sign") )
					signExecutable(nekoDir+"/"+projectName+".exe");

				copyRuntimeFiles(hxml, "Neko", nekoDir, NEKO_RUNTIME_FILES_WIN, false);

				copyExtraFilesIn(extraFiles, nekoDir);
				if( zipping )
					zipFolder( baseRedistDir+"/neko.zip", nekoDir);
			}

			// SWF
			if( content.indexOf("-swf ")>=0 ) {
				var swfDir = '$baseRedistDir/flash/$projectName';
				initRedistDir(swfDir, extraFiles);

				Lib.println("Building "+hxml+"...");
				compile(hxml);

				Lib.println("Packaging "+swfDir+"...");
				var out = getHxmlOutput(hxml,"-swf");
				copy(out, swfDir+"/"+projectName+".swf");
				copyRuntimeFiles(hxml, "SWF", swfDir, SWF_RUNTIME_FILES_WIN, false);

				var script = [
					'@echo off',
					'start flashPlayer.bin $projectName.swf',
				];
				createTextFile('$swfDir/Play $projectName.bat', script.join("\n"));

				copyExtraFilesIn(extraFiles, swfDir);
				if( zipping )
					zipFolder( baseRedistDir+"/swf.zip", swfDir);
			}
		}

		cleanUpExit();
		Lib.println("Done.");
		Sys.exit(0);
	}

	static function signExecutable(exePath:String) {
		Lib.println("Code signing executable...");

		// Check EXE
		if( !sys.FileSystem.exists(exePath) )
			error("Cannot sign executable, file not found: "+exePath);

		var fp = FilePath.fromFile(exePath);
		if( fp.extension!="exe" ) {
			Lib.println("  Warning: only supported on Windows executables");
			return false;
		}


		// Check if MS SignTool is installed
		if( !checkExeInPath("signtool.exe") )
			error('You need "signtool.exe" in PATH. You can get it by installing Microsoft Windows SDK (only pick "signing tools").');

		// Get PFX path from either argument or env "CSC_LINK"
		var pfx : Null<String> = null;
		if( hasParameter("-pfx") && !hasParameter("-sign") )
			error('Argument "-pfx" implies to also have "-sign" arg.');
		if( hasParameter("-sign") ) {
			pfx = getParameter("-pfx");
			if( pfx==null || pfx=="" )
				pfx = Sys.getEnv("CSC_LINK");
			if( pfx==null || !sys.FileSystem.exists(pfx) )
				error("Certificate file (.pfx) is missing after -pfx argument.");
		}

		Lib.println('  Using certificate: $pfx');

		// Get password for env "CSC_KEY_PASSWORD" or by asking the user for it
		var pass = hasParameter("-pfx") ? null : Sys.getEnv("CSC_KEY_PASSWORD");
		if( pass==null ) {
			Sys.print("  Enter PFX password: ");
			pass = Sys.stdin().readLine();
		}
		var result = Sys.command('signtool.exe sign /f "$pfx" /fd SHA256 /t http://timestamp.digicert.com /p "$pass" $exePath');
		if( result!=0 )
			error('Code signing failed! (code $result)');

		return true;
	}

	static function cleanUpExit() {
		Lib.println("Cleaning up...");

		if( sys.FileSystem.exists(PAK_BUILDER_BIN) )
			sys.FileSystem.deleteFile(PAK_BUILDER_BIN);

		if( hasParameter("-pak") && sys.FileSystem.exists(PAK_BUILDER_OUT+".pak") )
			sys.FileSystem.deleteFile(PAK_BUILDER_OUT+".pak");
	}

	static function compile(hxmlPath:String) {
		// Compile
		if( Sys.command("haxe", [hxmlPath]) != 0 )
			error('Compilation failed!');

		// PAK
		if( hasParameter("-pak") ) {
			// Compile PAK builder
			if( !sys.FileSystem.exists(PAK_BUILDER_BIN) ) {
				Lib.println("Compiling PAK builder ("+Sys.getCwd()+")...");
				if( Sys.command("haxe -hl "+PAK_BUILDER_BIN+" -lib heaps -main hxd.fmt.pak.Build") != 0 )
					error("Could not compile PAK builder!");
			}

			// Ignore elements
			var extraArgs = [];
			Lib.println("Creating PAK...");
			var ignores = getIgnoredElements();
			if( ignores.names.length>0 )
				extraArgs.push("-exclude-names "+ignores.names.join(","));
			if( ignores.exts.length>0 )
				extraArgs.push("-exclude "+ignores.exts.join(","));

			if( extraArgs.length>0 )
				Sys.println("  Extra arguments: "+extraArgs.join(" "));

			// Run it
			if( Sys.command( "hl "+PAK_BUILDER_BIN+" -out "+PAK_BUILDER_OUT+" "+extraArgs.join(" ") ) != 0 ) {
				error("Failed to run HL to build PAK!");
			}
		}
	}

	static function copyRuntimeFiles(hxmlPath:String, targetName:String, targetDir:String, runTimeFiles:RuntimeFiles, useHl32bits:Bool) {
		if( verbose )
			Lib.println("Copying "+targetName+" runtime files to "+targetDir+"... ");

		var exes = [];
		for( r in runTimeFiles.files ) {
			if( r.lib==null || hxmlRequiresLib(hxmlPath, r.lib) ) {
				try {
					var fileName = useHl32bits && r.f32!=null ? r.f32 : r.f;
					var from = findFile(fileName, useHl32bits);

					if( verbose )
						Lib.println(" -> "+fileName + ( r.lib==null?"" : " [required by -lib "+r.lib+"] (source: "+from+")") );
					var toFile = r.executableFormat!=null ? StringTools.replace(r.executableFormat, "$", projectName) : fileName.indexOf("/")<0 ? fileName : fileName.substr(fileName.lastIndexOf("/")+1);
					var to = targetDir+"/"+toFile;
					if( r.executableFormat!=null && verbose )
						Lib.println(" -> Renamed executable to "+toFile);
					copy(from, to);
	
					// List executables
					if( r.executableFormat!=null )
						exes.push( FilePath.fromFile(targetDir+"/"+toFile) );
				} catch (e) {
					Lib.println(e.message);
				}

			}
		}

		// Copy PAK
		if( hasParameter("-pak") )
			copy(PAK_BUILDER_OUT+".pak", targetDir+"/res.pak");

		// Set EXEs icon
		if( hasParameter("-icon") && runTimeFiles.platform==Windows ) // Windows only
			for( exeFp in exes ) {
				var i = getParameter("-icon");
				if( i==null )
					error("Missing icon path");

				var iconFp = FilePath.fromFile( StringTools.replace( i, "\"", "") );

				iconFp.useSlashes();
				exeFp.useSlashes();

				Lib.println("Replacing EXE icon...");
				if( !sys.FileSystem.exists(iconFp.full) )
					error("Icon file not found: "+iconFp.full);

				if( verbose ) {
					Lib.println("  exe="+exeFp.full);
					Lib.println("  icon="+iconFp.full);
				}
				if( runTool('rcedit/rcedit.exe', ['"${exeFp.full}"', '--set-icon "${iconFp.full}" ']) != 0 )
					error("rcedit failed!");
			}

		// Sign exe (Windows only)
		if( hasParameter("-sign") && exes.length>0 && runTimeFiles.platform==Windows )
			for( fp in exes )
				signExecutable(fp.full);
	}


	static function runTool(path:String, args:Array<String>) : Int {
		var toolFp = FilePath.fromFile('$redistHelperDir/tools/$path');
		toolFp.useSlashes();
		var cmd = '"${toolFp.full}" ${args.join(" ")}';
		if( verbose )
			Lib.println("Executing tool: "+cmd);

		// Use sys.io.Process instead of Sys.command because of quotes ("") bug
		var p = new sys.io.Process(cmd);
		var code = p.exitCode();
		p.close();
		if( verbose && code!=0 )
			Lib.println('  Failed with error code $code');
		return code;
	}


	static function getIgnoredElements() {
		var out = {
			names: [],
			exts: [],
		}

		if( !hasParameter("-ignore") )
			return out;

		if( getParameter("-ignore")==null )
			error("Missing names or extensions after -ignore");

		var parts = getParameter("-ignore").split(",");
		for(p in parts) {
			p = StringTools.trim(p);
			if( p.indexOf("*.")>0 )
				error("Malformed ignored file name: "+p);
			else if( p.indexOf("*.")==0 )
				out.exts.push( p.substr(2) );
			else
				out.names.push(p);
		}
		return out;
	}

	static function getHxmlOutput(hxmlPath:String, lookFor:String) : Null<String> {
		if( hxmlPath==null )
			return null;

		if( !sys.FileSystem.exists(hxmlPath) )
			error("File not found: "+hxmlPath);

		try {
			var content = getFullHxml(hxmlPath);
			for( line in content.split(NEW_LINE) ) {
				if( line.indexOf(lookFor)>=0 )
					return StringTools.trim( line.split(lookFor)[1] );
			}
		} catch(e:Dynamic) {
			error("Could not read "+hxmlPath+" ("+e+")");
		}
		error("No "+lookFor+" output in "+hxmlPath);
		return null;
	}

	static function hxmlRequiresLib(hxmlPath:String, libId:String) : Bool {
		if( hxmlPath==null )
			return false;

		if( !sys.FileSystem.exists(hxmlPath) )
			error("File not found: "+hxmlPath);

		try {
			var fi = sys.io.File.read(hxmlPath, false);
			var content = fi.readAll().toString();
			if( content.indexOf("-lib "+libId)>=0 )
				return true;
			for(line in content.split(NEW_LINE))
				if( line.indexOf(".hxml")>=0 )
					return hxmlRequiresLib(line, libId);
		} catch(e:Dynamic) {
			error("Could not read "+hxmlPath+" ("+e+")");
		}
		return false;
	}	
}
