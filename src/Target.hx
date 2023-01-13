import sys.FileSystem;
import haxe.io.Path;

typedef RuntimeFiles = {
	var platform: Platform;
	var dir:String;
	var files:Array<RuntimeFile>;
}

typedef RuntimeFile = {
	var ?lib: Null<String>;
	var f: String;
	var ?d: String;
	var ?format: String;
}

enum Platform {
	Windows;
	Mac;
	Linux;
}

class Target {
	var distDir: String;
	var projDir: String;
	var projName: String;

	public function new(dd:String, pd: String, pn:String) {
		distDir = dd;
		projDir = pd;
		projName = pn;
	}

	public function compile(hxml:String, outputDir:String) {}

    function copyRuntimeFiles(hxml:Array<String>, targetDir:String, runTimeFiles:RuntimeFiles) {
		targetDir = Path.normalize(targetDir);
		runTimeFiles.dir = Path.normalize(runTimeFiles.dir);

		Term.print("Packaging " + targetDir + "...");

		for(r in runTimeFiles.files) {
			if(r.lib != null && !hxmlRequiresLib(hxml, r.lib)) continue;

			var outputName = (r.format == null) ? r.f : StringTools.replace(r.format, "$", projName);
			var from = distDir + '/' + runTimeFiles.dir + '/' + r.f;

			var fullOutputDir = targetDir + '/' + (r.d != null ? r.d : '');

			if(!FileSystem.exists(fullOutputDir)) {
				FileUtil.createDirectory(fullOutputDir);
			}
			
			var to = fullOutputDir + outputName;
			
			if(Term.hasOption('verbose')) {
				Term.print(" -> Copying " + r.f + (r.lib == null ? "" : " [required by " + r.lib + "]"));
				if(r.format != null) Term.print(" -> Renaming " + r.f + " to " + to);
			}
			
			FileUtil.copyFile(from, to);
		}

		// for steam, grab the appid
		if(hxmlRequiresLib(hxml, 'hlsteam') && FileSystem.exists(projDir + '/steam_appid.txt')) {
			FileUtil.copyFile(projDir + '/steam_appid.txt', targetDir + '/steam_appid.txt');
		}

		Term.print("Created " + targetDir);
	}

    function hxmlRequiresLib(hxml:Array<String>, libId:String) : Bool {
		if(libId == null)
			return false;

		for(line in hxml) {
			if(line.indexOf("-lib " + libId) >= 0) {
				return true;
			}
		}

		return false;
	}

	function getHxmlParam(hxml:Array<String>, lookFor:String) : Null<String> {
		for(line in hxml) {
			if(line.indexOf(lookFor)>=0)
				return StringTools.trim(line.split(lookFor)[1]);
		}

		Term.warning("No " + lookFor + " param found in hxml file.");
		return null;
	}

	function runTool(path:String, args:Array<String>) : Int {
		var toolFp = '$distDir/tools/$path';
		var cmd = '"${toolFp}" ${args.join(" ")}';

		Term.print("Executing tool: " + cmd);

		// Use sys.io.Process instead of Sys.command because of quotes ("") bug
		var p = new sys.io.Process(cmd);
		var code = p.exitCode();
		p.close();
		if(code != 0)
			Term.warning('Failed with error code $code');

		return code;
	}

	function runCommand(tool:String, args:Array<String>) : Int {
		var cmd = '$tool ${args.join(" ")}';

		var p = new sys.io.Process(cmd);
		var code = p.exitCode();
		p.close();
		
		return code;
	}

	public static function parseHxml(dir:String, f:String): Array<String> {
		dir = Path.normalize(dir);
		f = Path.normalize(f);

		var lines = sys.io.File.getContent(dir + '/' + f).split('\n');
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
}