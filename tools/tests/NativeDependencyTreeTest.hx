import targets.hashlink.NativeDependencies;
import targets.hashlink.NativeDependencies.ResolvedNativeFile;

@:access(targets.hashlink.NativeDependencies)
class NativeDependencyTreeTest {
	static function check(condition:Bool, message:String):Void {
		if(!condition) throw message;
	}

	static function main():Void {
		var files:Array<ResolvedNativeFile> = [];
		var destinations = new Map<String, ResolvedNativeFile>();
		var queued = new Map<String, Bool>();
		function add(name:String, reason:String, ?parent:ResolvedNativeFile):ResolvedNativeFile {
			NativeDependencies.addFile('README.md', name, reason, files, destinations, queued, parent);
			return destinations.get(name);
		}
		var runtime = add('app.exe', 'HashLink runtime');
		var native = add('plugin.hdll', 'HashLink native library plugin');
		var shared = add('shared.dll', 'native dependency of app.exe', runtime);
		add('shared.dll', 'native dependency of plugin.hdll', native);
		add('shared.dll', 'native dependency of plugin.hdll', native);
		add('shared.dll', 'hxdist.json include');
		add('app.exe', 'native dependency of shared.dll', shared);
		check(files.length == 3, 'Duplicates must not add packaged files');
		check(native.dependencies.length == 1, 'Repeated imports must not add duplicate edges');
		var lines = NativeDependencies.treeLines(files);
		check(lines.length == 7, 'Shared references and cycles must terminate without hiding parent edges');
		check(StringTools.startsWith(lines[1], '|-- app.exe [HashLink runtime] <- '), 'Runtime provenance and source');
		check(StringTools.startsWith(lines[2], '|   `-- shared.dll <- '), 'Dependency hierarchy');
		check(StringTools.startsWith(lines[3], '|       `-- app.exe <- ') && StringTools.endsWith(lines[3], '(already shown)'), 'Cycle reference');
		check(StringTools.startsWith(lines[4], '|-- plugin.hdll [HashLink native library plugin] <- '), 'Bytecode provenance');
		check(StringTools.startsWith(lines[5], '|   `-- shared.dll <- ') && StringTools.endsWith(lines[5], '(already shown)'), 'Shared dependency retains second parent');
		check(StringTools.startsWith(lines[6], '`-- shared.dll [hxdist.json include] <- '), 'Explicit inclusion retains root provenance');
		for(line in lines) Sys.println(line);
		Sys.println('Native dependency tree tests passed.');
	}
}
