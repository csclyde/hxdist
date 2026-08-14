import haxe.io.Path;
import sys.FileSystem;

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
		var value = findHxmlParam(hxml, lookFor);
		if(value != null) return value;

		Term.warning('No ' + lookFor + ' param found in hxml file.');
		return null;
	}

	public static function hasHxmlParam(hxml:Array<String>, lookFor:String):Bool {
		return findHxmlParam(hxml, lookFor) != null;
	}

	static function findHxmlParam(hxml:Array<String>, lookFor:String):Null<String> {
		for(i in 0...hxml.length) {
			var argument = hxml[i];
			if(argument == lookFor) {
				if(i + 1 < hxml.length && !isOption(hxml[i + 1]))
					return hxml[i + 1];
				return null;
			}
			if(StringTools.startsWith(argument, lookFor + '='))
				return argument.substr(lookFor.length + 1);
		}
		return null;
	}

	static function isOption(argument:String):Bool {
		return StringTools.startsWith(argument, '-');
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
		var path = resolveHxmlPath(dir, f);
		return parseHxmlFile(path, new Map<String, Bool>());
	}

	static function parseHxmlFile(path:String, visiting:Map<String, Bool>):Array<String> {
		var normalized = Path.normalize(FileSystem.fullPath(path));
		var key = Sys.systemName() == 'Windows' ? normalized.toLowerCase() : normalized;
		if(visiting.exists(key))
			Term.error('Circular HXML include detected: $normalized');
		visiting.set(key, true);

		var result:Array<String> = [];
		var lines = sys.io.File.getContent(normalized).split('\n');
		for(index in 0...lines.length) {
			var line = stripComment(lines[index]);
			if(StringTools.trim(line) == '') continue;

			var arguments = tokenizeHxmlLine(line, normalized, index + 1);
			if(arguments.length == 0) continue;

			if(arguments.length == 1 && isHxmlInclude(arguments[0])) {
				var includePath = resolveHxmlPath(Path.directory(normalized), arguments[0]);
				result = result.concat(parseHxmlFile(includePath, visiting));
			}
			else {
				result = result.concat(arguments);
			}
		}

		visiting.remove(key);
		return result;
	}

	static function resolveHxmlPath(dir:String, file:String):String {
		var path = Path.isAbsolute(file) ? file : Path.normalize(dir + '/' + file);
		path = Path.normalize(path);
		if(!FileSystem.exists(path) || FileSystem.isDirectory(path))
			Term.error('HXML file does not exist: $path');
		return FileSystem.fullPath(path);
	}

	static function isHxmlInclude(argument:String):Bool {
		return !StringTools.startsWith(argument, '-') && StringTools.endsWith(argument.toLowerCase(), '.hxml');
	}

	static function stripComment(line:String):String {
		var quote = '';
		for(i in 0...line.length) {
			var character = line.charAt(i);
			if((character == '"' || character == "'") && (i == 0 || line.charAt(i - 1) != '\\')) {
				if(quote == '') quote = character;
				else if(quote == character) quote = '';
			}
			else if(character == '#' && quote == '') {
				return line.substr(0, i);
			}
		}
		return line;
	}

	static function tokenizeHxmlLine(line:String, path:String, lineNumber:Int):Array<String> {
		var result:Array<String> = [];
		var current = '';
		var quote = '';
		var hasToken = false;
		var i = 0;
		while(i < line.length) {
			var character = line.charAt(i);
			if(quote != '' && character == '\\' && i + 1 < line.length) {
				var next = line.charAt(i + 1);
				if(next == quote || next == '\\') {
					current += next;
					hasToken = true;
					i += 2;
					continue;
				}
			}
			if(quote == '') {
				if(character == '"' || character == "'") {
					quote = character;
					hasToken = true;
				}
				else if(character == ' ' || character == '\t' || character == '\r') {
					if(hasToken) {
						result.push(current);
						current = '';
						hasToken = false;
					}
				}
				else {
					current += character;
					hasToken = true;
				}
			}
			else if(character == quote) {
				quote = '';
			}
			else {
				current += character;
				hasToken = true;
			}
			i++;
		}
		if(quote != '')
			Term.error('Unterminated quote in $path on line $lineNumber.');
		if(hasToken) result.push(current);
		return result;
	}
}
