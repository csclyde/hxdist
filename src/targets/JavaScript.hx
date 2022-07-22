package targets;

class JavaScript extends Target {
    public function new(dd:String, pd: String, pn:String) {
        super(dd, pd, pn);
    }

    public override function compile(hxml:String, outputDir:String) {
        if(Sys.command("haxe", [hxml]) != 0)
			Term.error('Compilation failed!');

        var hxmlContent = FileUtil.parseHxml(projDir, hxml);

        createPackage(hxmlContent, outputDir + "/js/", files);

		FileUtil.zipFolder(outputDir + '/${projName}_js.zip', outputDir + "/js");
	}

    function createPackage(hxml:Array<String>, packageDir:String, files:Target.RuntimeFiles) {
		Term.print("Packaging " + packageDir + "...");
		FileUtil.initDistDir(packageDir);
		FileUtil.createDirectory(packageDir);

		// Runtimes
		copyRuntimeFiles(hxml, packageDir, files);

		// Copy HL bin file
		var out = getHxmlParam(hxml, "-js");
		FileUtil.copy(out, packageDir + "/game.js");
	}

    var files : Target.RuntimeFiles = {
		platform: null,
        dir: 'dist_files/js/',
		files: [
			// common
			{ f:"index.html" },
		],
	}
}