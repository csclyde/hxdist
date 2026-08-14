package targets.hashlink;

import haxe.io.Path;
import sys.FileSystem;
import FileUtil;
import Target;
import Term;

class HashLink extends Target {
	public function new(dd:String, pd:String, pn:String) {
		super(dd, pd, pn);
	}

	public override function compile(hxml:String, outputDir:String) {
		if(Sys.command('haxe', [hxml]) != 0)
			Term.error('Compilation failed!');

		var hxmlContent = Target.parseHxml(projDir, hxml);
		var out = getHxmlParam(hxmlContent, '-hl');
		if(out == null || out == '')
			Term.error('The HashLink build did not provide a -hl output file.');
		if(!Path.isAbsolute(out)) out = Path.normalize(projDir + '/' + out);
		if(!FileSystem.exists(out))
			Term.error('HashLink output was not created: $out');

		var platform = Sys.systemName();
		if(platform == 'Windows') {
			var packageDir = '$outputDir/$projName';
			createPackage(out, packageDir, platform);

			var icon = '$projDir/meta/$projName.ico';
			if(FileSystem.exists(icon)) {
				Term.print('Setting exe icon...');
				runTool('rcedit.exe', ['$packageDir/$projName.exe', '--set-icon "$icon"']);
			}
			else {
				Term.print('No Windows icon found; skipping icon update.');
			}

			FileUtil.zipFolder('$outputDir/${projName}_hl_win.zip', '$packageDir/');
		}
		else if(platform == 'Linux') {
			var packageDir = '$outputDir/$projName';
			createPackage(out, packageDir, platform);

			Term.print('Updating the run script with project variables...');
			var runScript = sys.io.File.getContent('$packageDir/run.sh');
			runScript = StringTools.replace(runScript, '$' + 'PROJ_NAME', projName);
			sys.io.File.saveContent('$packageDir/run.sh', runScript);

			Term.print('Updating the Linux files with execute permissions...');
			if(Sys.command('chmod', ['+x', '$packageDir/$projName.x64']) != 0)
				Term.warning('Could not mark the Linux executable as executable.');
			if(Sys.command('chmod', ['+x', '$packageDir/run.sh']) != 0)
				Term.warning('Could not mark run.sh as executable.');

			if(Sys.command('zip', ['-j', '-r', '$outputDir/${projName}_hl_linux.zip', '$packageDir']) != 0)
				Term.error('Could not create the Linux zip archive.');
		}
		else if(platform == 'Mac') {
			var packageDir = '$outputDir/$projName';
			createPackage(out, packageDir, platform);

			if(Sys.command('chmod', ['+x', '$packageDir/$projName']) != 0)
				Term.warning('Could not mark the macOS executable as executable.');

			FileUtil.zipFolder('$outputDir/${projName}_hl_mac_itch.zip', '$outputDir/');
			FileUtil.zipFolder('$outputDir/${projName}_hl_mac_steam.zip', '$outputDir/$projName/');
		}
		else {
			Term.error('Unsupported host platform: $platform');
		}
	}

	function createPackage(bootPath:String, packageDir:String, platform:String):Void {
		Term.print('Discovering HashLink native dependencies...');
		var files = NativeDependencies.resolve(bootPath, projDir, projName, platform);
		FileUtil.createDirectory(packageDir);

		var hasSteam = false;
		for(file in files) {
			var destination = '$packageDir/${file.destination}';
			if(Term.hasOption('verbose'))
				Term.print(' -> Copying ${file.destination} [${file.reason}] from ${file.source}');
			FileUtil.copyFile(file.source, destination);
			if(file.destination.toLowerCase() == 'steam.hdll') hasSteam = true;
		}

		FileUtil.copyFile(bootPath, '$packageDir/hlboot.dat');
		if(platform == 'Linux') {
			var dollar = String.fromCharCode(36);
			var runScript = '#!/bin/sh\n'
				+ 'LD_LIBRARY_PATH="' + dollar + '(dirname "' + dollar + '0")" "' + dollar + '(dirname "' + dollar + '0")/' + projName + '.x64"\n';
			sys.io.File.saveContent('$packageDir/run.sh', runScript);
		}

		var appId = '$projDir/meta/steam_appid.txt';
		if(hasSteam && FileSystem.exists(appId))
			FileUtil.copyFile(appId, '$packageDir/steam_appid.txt');

		Term.print('Created $packageDir');
	}
}
