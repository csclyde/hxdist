import dn.Lib;

class Term {
    public static function error(msg:Dynamic) {
		Lib.println("");
		Lib.println("ERROR - "+Std.string(msg));
		cleanUpExit();
		Sys.exit(1);
	}

    public static function usage() {
		Lib.println("");
		Lib.println("USAGE:");
		Lib.println("  haxelib run redistHelper <hxml1> [<hxml2>] [<hxml3>] [customFile1] [customFile2]");
		Lib.println("");
		Lib.println("EXAMPLES:");
		Lib.println("  haxelib run redistHelper myGame.hxml");
		Lib.println("  haxelib run redistHelper myGame.hxml docs/CHANGELOG.md docs/LICENSE");
		Lib.println("  haxelib run redistHelper myGame.hxml docs/README@read_me.txt");
		Lib.println("  haxelib run redistHelper myGame.hxml docs");
		Lib.println("  haxelib run redistHelper myGame.hxml docs -ignore backups,*.zip");
		Lib.println("  haxelib run redistHelper myGame.hxml -sign -pfx path/to/myCertificate.pfx");
		Lib.println("");
		Lib.println("OPTIONS:");
		Lib.println("  -o <outputDir>: change the default redistHelper output dir (default: \"redist/\")");
		Lib.println("  -p <projectName>: change the default project name (if not provided, it will use the name of the parent folder where this script is called)");
		Lib.println("  -icon <iconFilePath>: replace EXE icon (only works for Windows and HL target)");
		Lib.println("  -linux: package an Hashlink (HL) for Linux. This requires having an HXML using lib SDL");
		Lib.println("  -hl32: when building Hashlink targets, this option will also package a 32bits version of the HL runtime in separate redist folders.");
		Lib.println("  -zip: create a zip file for each build");
		Lib.println("  -ignore <namesOrExtensions>: List of files to be ignored when copying extra directories (typically temp files or similar things). Names should be separated by a comma \",\", no space. To ignore file extensions, use the \"*.ext\" format. See examples.");
		Lib.println("  -pak: generate a PAK file from the existing Heaps resource folder");
		Lib.println("  -sign: code sign the executables using a PFX certificate. A password will be requested to use the certificate. If the -pfx argument is not provided, the PFX path will be looked up in the environment var CSC_LINK. The password will also be looked up in the environment var CSC_KEY_PASSWORD.");
		Lib.println("  -pfx <pathToPfxFile>: Use provided PFX file to sign the executables (implies the use of -sign)");
		Lib.println("  -h: show this help");
		Lib.println("  -v: verbose mode (display more informations)");
		Lib.println("");
		Lib.println("NOTES:");
		Lib.println("  - All specified \"Custom files\" will be copied in each redist folders (can be useful for README, LICENSE, etc.).");
		Lib.println("  - You can specify folders to copy among \"Custom files\".");
		Lib.println("  - Custom files can be renamed after copy, just add \"@\" followed by the final name after the file path. Example:");
		Lib.println("      haxelib run redistHelper myGame.hxml docs/README@read_me.txt");
		Lib.println("      The \"README\" file from docs/ will be renamed to \"read_me.txt\" in the target folder.");
		Lib.println("");
		Sys.exit(0);
	}

    public static function hasParameter(id:String) {
		for( p in Sys.args() )
			if( p==id )
				return true;
		return false;
	}

    public static function getParameter(id:String) : Null<String> {
		var isNext = false;
		for( p in Sys.args() )
			if( p==id )
				isNext = true;
			else if( isNext )
				return p;

		return null;
	}

    public static function getIsolatedParameters() : Array<String> {
		var all = [];
		var ignoreNext = false;
		for( p in Sys.args() ) {
			if( p.charAt(0)=="-" ) {
				if( !SINGLE_PARAMETERS.exists(p) )
					ignoreNext = true;
			}
			else if( !ignoreNext )
				all.push(p);
			else
				ignoreNext = false;
		}

		return all;
	}
}