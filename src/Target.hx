import haxe.io.Path;

class Target {
	var distDir:String;
	var projDir:String;
	var projName:String;

	public function new(dd:String, pd:String, pn:String) {
		distDir = dd;
		projDir = pd;
		projName = pn;
	}

	public function compile(hxml:String, outputDir:String) {}

	function getHxmlParam(hxml:Array<String>, lookFor:String):Null<String> {
		for(i in 0...hxml.length) {
			var line = StringTools.trim(hxml[i]);
			if(line == lookFor && i + 1 < hxml.length)
				return StringTools.trim(hxml[i + 1]);
			if(StringTools.startsWith(line, lookFor + ' '))
				return StringTools.trim(line.substr(lookFor.length));
		}

		Term.warning('No ' + lookFor + ' param found in hxml file.');
		return null;
	}

	function runTool(path:String, args:Array<String>):Int {
		var toolFp = '$distDir/tools/$path';
		var cmd = '"${toolFp}" ${args.join(" ")}';

		Term.print('Executing tool: ' + cmd);

		var p = new sys.io.Process(cmd);
		var code = p.exitCode();
		p.close();
		if(code != 0)
			Term.warning('Failed with error code $code');

		return code;
	}

	public static function parseHxml(dir:String, f:String):Array<String> {
		dir = Path.normalize(dir);
		f = Path.normalize(f);

		var lines = sys.io.File.getContent(dir + '/' + f).split('\n');
		var finalLines:Array<String> = [];

		for(line in lines) {
			line = StringTools.trim(line.split('#')[0]);
			if(line == '') continue;

			if(StringTools.endsWith(line, '.hxml') && !StringTools.startsWith(line, '-cmd ')) {
				var includePath = Path.normalize(Path.directory(dir + '/' + f) + '/' + line);
				finalLines = finalLines.concat(parseHxml(Path.directory(includePath), Path.withoutDirectory(includePath)));
			}
			else {
				finalLines.push(line);
			}
		}

		return finalLines;
	}
}
