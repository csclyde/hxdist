class Term {
	public static var options: Map<String, Array<String>> = [
		'help' => ['-h', '-help', '--help'],
		'verbose' => ['-v', '--verbose'],
		'zip' => ['-z', '-zip', '--zip'],
		'sign' => ['-sign', '--sign'],
		'win' => ['-win', '--win', '-windows', '--windows'],
		'mac' => ['-mac', '--mac', '-macos', '--macos'],
		'linux' => ['-linux', '--linux', '-lin', '--lin'],
	];

	public static var params: Map<String, Array<String>> = [
		'proj_name' => ['-p'],
		'output_dir' => ['-o'],
		'icon' => ['-icon'],
		'pfx' => ['-pfx'],
	];

	public static var selectedOptions: Array<String> = [];
	public static var selectedParams: Map<String, String> = [];
	public static var hxmlPaths: Array<String> = [];
	public static var projectDir: String = '';

	public static function parseArgs() {
		var nextParam = '';
		var foundArg = false;

		projectDir = Sys.args().pop();

		for(arg in Sys.args()) {
			foundArg = false;

			// if nextParam is set, we are capturing the param value
			if(nextParam != '') {
				selectedParams[nextParam] = arg;
				nextParam = '';
				continue;
			}

			// check for options
			for(k => v in options) {
				if(v.contains(arg)) {
					selectedOptions.push(k);
					foundArg = true;
				}
			}

			if(foundArg) continue;

			// check for params
			for(k => v in params) {
				if(v.contains(arg)) {
					selectedParams[k] = '';
					nextParam = k;
					foundArg = true;
				}
			}

			if(foundArg) continue;

			// if we get here, the param hasnt been located yet. treat as hxml
			if(arg.indexOf('.hxml') >= 0) {
				hxmlPaths.push(arg);
			}
		}

	}

	public static function print(msg:Dynamic) {
		Sys.println(Std.string(msg));
	}

	public static function warning(msg:Dynamic) {
		Sys.println("WARNING - " + Std.string(msg));
	}

    public static function error(msg:Dynamic) {
		Sys.println("ERROR - " + Std.string(msg));
		FileUtil.cleanUpExit();
		Sys.exit(1);
	}

    public static function usage() {
		Sys.println("");
		Sys.println("USAGE:");
		Sys.println("  haxelib run redistHelper <hxml1> [<hxml2>] [<hxml3>] [customFile1] [customFile2]");
		Sys.println("");
		Sys.println("EXAMPLES:");
		Sys.println("  haxelib run redistHelper myGame.hxml");
		Sys.println("  haxelib run redistHelper myGame.hxml docs/CHANGELOG.md docs/LICENSE");
		Sys.println("  haxelib run redistHelper myGame.hxml docs/README@read_me.txt");
		Sys.println("  haxelib run redistHelper myGame.hxml docs");
		Sys.println("  haxelib run redistHelper myGame.hxml docs -ignore backups,*.zip");
		Sys.println("  haxelib run redistHelper myGame.hxml -sign -pfx path/to/myCertificate.pfx");
		Sys.println("");
		Sys.println("OPTIONS:");
		Sys.println("  -o <outputDir>: change the default redistHelper output dir (default: \"redist/\")");
		Sys.println("  -p <projectName>: change the default project name (if not provided, it will use the name of the parent folder where this script is called)");
		Sys.println("  -icon <iconFilePath>: replace EXE icon (only works for Windows and HL target)");
		Sys.println("  -linux: package an Hashlink (HL) for Linux. This requires having an HXML using lib SDL");
		Sys.println("  -hl32: when building Hashlink targets, this option will also package a 32bits version of the HL runtime in separate redist folders.");
		Sys.println("  -zip: create a zip file for each build");
		Sys.println("  -ignore <namesOrExtensions>: List of files to be ignored when copying extra directories (typically temp files or similar things). Names should be separated by a comma \",\", no space. To ignore file extensions, use the \"*.ext\" format. See examples.");
		Sys.println("  -pak: generate a PAK file from the existing Heaps resource folder");
		Sys.println("  -sign: code sign the executables using a PFX certificate. A password will be requested to use the certificate. If the -pfx argument is not provided, the PFX path will be looked up in the environment var CSC_LINK. The password will also be looked up in the environment var CSC_KEY_PASSWORD.");
		Sys.println("  -pfx <pathToPfxFile>: Use provided PFX file to sign the executables (implies the use of -sign)");
		Sys.println("  -h: show this help");
		Sys.println("  -v: verbose mode (display more informations)");
		Sys.println("");
		Sys.println("NOTES:");
		Sys.println("  - All specified \"Custom files\" will be copied in each redist folders (can be useful for README, LICENSE, etc.).");
		Sys.println("  - You can specify folders to copy among \"Custom files\".");
		Sys.println("  - Custom files can be renamed after copy, just add \"@\" followed by the final name after the file path. Example:");
		Sys.println("      haxelib run redistHelper myGame.hxml docs/README@read_me.txt");
		Sys.println("      The \"README\" file from docs/ will be renamed to \"read_me.txt\" in the target folder.");
		Sys.println("");
		Sys.exit(0);
	}

    public static function hasOption(opt:String) {
		return selectedOptions.contains(opt);
	}

	public static function getParam(p:String) {
		return selectedParams[p];
	}

	public static function hasParam(p:String) {
		return selectedParams[p] != null;
	}
}