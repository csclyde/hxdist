import haxe.io.Path;
import FileUtil;
import targets.*;

class Main {
	static var distDir = "";
	static var projectDir = "";
	static var projectName = "unknown";
	static var verbose = false;
	static var zipping = false;

	static function main() {
		Term.parseArgs();

		if(Sys.args().length == 0 || Term.hasOption("help")) {
			Term.usage();
		}

		verbose = Term.hasOption("verbose");
		zipping = Term.hasOption("zip");

		// Set CWD to the directory haxelib was called
		distDir = Path.normalize(Sys.getCwd());
		projectDir = Path.normalize(Term.projectDir);
		projectDir = Path.removeTrailingSlashes(projectDir);
		
		if(verbose) {
			Term.print("hxdist Dir = " + distDir);
			Term.print("Project Dir = " + projectDir);
		}

		try {
			Sys.setCwd(projectDir);
		}
		catch(e:Dynamic) {
			Term.error("The final param must be your projects directory (the one with hxml files). If hxdist is called with 'haxelib run', this is automatically provided.");
		}

		if(Term.hxmlPaths.length == 0) {
			Term.error("No hxml file provided.");
		}

		// Project name
		projectName = Term.getParam("proj_name");

		if(projectName == null) {
			var split = projectDir.split("/");
			projectName = split[split.length - 1];

		}

		Term.print("Project name: " + projectName);

		// Output folder
		var outputDir = Term.getParam("output_dir");
		if(outputDir == null) {
			outputDir = "dist";
		}

		// Prepare base folder
		FileUtil.removeDirectory(outputDir);

		// Parse HXML files given as parameters
		for(hxml in Term.hxmlPaths) {
			Term.print("Parsing " + hxml + "...");
			var hxmlContent = Target.parseHxml(projectDir, hxml);

			// HL
			if(hxmlContent.filter((c) -> c.indexOf("-hl ") >= 0 && c.indexOf(".hl") >= 0).length > 0) {
				Term.print("Building for HashLink target...");
				var target = new HashLink(distDir, projectDir, projectName);
				target.compile(hxml, outputDir);
			}
			// JS
			else if(hxmlContent.filter((c) -> c.indexOf("-js ") >= 0).length > 0) {
				Term.print("Building for JavaScript target...");
				var target = new JavaScript(distDir, projectDir, projectName);
				target.compile(hxml, outputDir);
			}
		
		}

		FileUtil.cleanUpExit();
		Term.print("Done.");
		Sys.exit(0);
	}
}
