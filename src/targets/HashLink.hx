package targets;

import sys.FileSystem;

class HashLink extends Target {
    public function new(dd:String, pd: String, pn:String) {
        super(dd, pd, pn);
    }

    public override function compile(hxml:String, outputDir:String) {
        if(Sys.command("haxe", [hxml]) != 0)
			Term.error('Compilation failed!');

        var hxmlContent = Target.parseHxml(projDir, hxml);

		// WINDOWS
		if(Sys.systemName() == 'Windows') {
			var packageDir = '$outputDir/$projName';

			createPackage(hxmlContent, packageDir, winFiles);

			Term.print('Setting exe icon...');
			runTool('rcedit.exe', ['$packageDir/$projName.exe', '--set-icon "$projDir/meta/$projName.ico"']);

			FileUtil.zipFolder('$outputDir/${projName}_hl_win.zip', '$packageDir/');
		} 
		// LINUX
		else if(Sys.systemName() == 'Linux') {
			var packageDir = '$outputDir/$projName';

			createPackage(hxmlContent, packageDir, linuxFiles);
			
			Term.print("Updating the run script with project variables...");
			var runScript = sys.io.File.getContent('$packageDir/run.sh');
			runScript = StringTools.replace(runScript, "$PROJ_NAME", projName);
			sys.io.File.saveContent('$packageDir/run.sh', runScript);

			Term.print("Updating the linux files with execute permissions...");
			Sys.command('chmod', ['+x', '$packageDir/$projName.x64']);
			Sys.command('chmod', ['+x', '$packageDir/run.sh']);
			

			// FileUtil.zipFolder('$outputDir/${projName}_hl_linux_itch.zip', '$outputDir/');
			// FileUtil.zipFolder('$outputDir/${projName}_hl_linux_steam.zip', '$outputDir/$projName/');

			// Sys.command('cd', ['$packageDir/']);
			Sys.command('zip', ['-j', '-r', '$outputDir/${projName}_hl_linux.zip', '$packageDir']);
		} 
		// MAC
		else if(Sys.systemName() == 'Mac') {
			var packageDir = '$outputDir/$projName';

			createPackage(hxmlContent, packageDir, macFiles);
			
			Term.print("Updating the mac files with execute permissions...");
			Sys.command('chmod', ['+x', '$packageDir/$projName']);
			
			FileUtil.zipFolder(outputDir + '/${projName}_hl_mac_itch.zip', '$outputDir/');
			FileUtil.zipFolder(outputDir + '/${projName}_hl_mac_steam.zip', '$outputDir/$projName/');
			
			// Term.print("Input the Developer ID (Developer ID Application: Simon Smith (TK421)):");
			// var appId:String = Sys.stdin().readLine();

			// Term.print("Codesigning the app bundle...");
			// Sys.command('codesign', ['-s', appId, '--timestamp', '--options', 'runtime', '-f', '--entitlements', '$outputFolder/entitlements.plist', '--deep', '$outputFolder/$projName.app']);
			
			// Term.print("Zipping the signed bundle...");
			// Sys.command('ditto', ['-c', '-k' ,'--keepParent', '$outputFolder/$projName.app', '$outputFolder/$projName.zip']);
			
			// Term.print("Enter notarytool profile name:");
			// var notaryProfile:String = Sys.stdin().readLine();

			// Term.print("Notarizing app (might take a while)...");
			// Sys.command('xcrun notarytool', ['submit', '$outputFolder/$projName.zip', '--keychain-profile', notaryProfile, '--wait']);
			
			// Term.print("Stapling notary to app...");
			// Sys.command('xcrun stapler', ['staple', '$outputFolder/$projName.app']);

		}
	}
	
    function createPackage(hxml:Array<String>, packageDir:String, files:Target.RuntimeFiles) {
		Term.print("Packaging " + packageDir + "...");
		FileUtil.createDirectory(packageDir);
		
		copyRuntimeFiles(hxml, packageDir, files);
		
		// Copy HL bin file
		var out = getHxmlParam(hxml, "-hl");
		
		FileUtil.copyFile(out, '$packageDir/hlboot.dat');

		// for steam, grab the appid
		if(hxmlRequiresLib(hxml, 'hlsteam') && FileSystem.exists('$projDir/meta/steam_appid.txt')) {
			FileUtil.copyFile('$projDir/meta/steam_appid.txt', '$packageDir/steam_appid.txt');
		}
	}

	var commonFiles:Target.RuntimeFiles = {
		platform: null,
		dir: 'dist_files/hl_common/',
		files: [

		]
	}

    var winFiles : Target.RuntimeFiles = {
		platform: Windows,
        dir: 'dist_files/hl_win/',
		files: [
			// common
			{ f:"gamecontrollerdb.txt" },
			{ f:"fmt.hdll" },
			{ f:"ssl.hdll" },
			{ f:"hlimgui.hdll", lib:"hlimgui" },
			{ f:"sdl.hdll", lib:"hlsdl" },
			{ f:"directx.hdll", lib:"hldx" },
			{ f:"steam.hdll", lib:"hlsteam" },
			{ f:"openal.hdll", lib:"heaps" },
			{ f:"ui.hdll", lib:"heaps" },
			{ f:"uv.hdll", lib:"heaps" },
			{ f:"heaps.hdll", lib:"heaps" },

			{ f:"hl.exe", format:"$.exe" },
			{ f:"libhl.dll" },
			
			
			{ f:"OpenAL32.dll", lib:"heaps" },
			{ f:"SDL2.dll", lib:"hlsdl" },
			{ f:"steam_api64.dll", lib:"hlsteam" },
		],
	}

	var macFiles: Target.RuntimeFiles = {
		platform: Mac,
        dir: 'dist_files/hl_mac/',
		files: [
			{ f:"hl", format:"$" },
			{ f:"gamecontrollerdb.txt" },
			{ f:"libhl.dylib" },
			{ f:"mysql.hdll" },
			{ f:"entitlements.plist", d: "../" },
			// { f:"Info.plist", d: "Contents/" },

			{ f:"fmt.hdll" },
			{ f:"libpng16.16.dylib" },
			{ f:"libvorbis.0.dylib" },
			{ f:"libogg.0.dylib" },
			{ f:"libvorbisfile.3.dylib" },
			{ f:"libturbojpeg.0.dylib" },
			{ f:"libz.1.dylib" },

			{ f:"ssl.hdll" },
			{ f:"libmbedtls.14.dylib" },
			{ f:"libmbedcrypto.7.dylib" },
			{ f:"libmbedx509.1.dylib" },

			{ lib:"hlsdl", f:"sdl.hdll" },
			{ lib:"hlsdl", f:"libSDL2-2.0.0.dylib" },
			
			{ lib:"heaps", f:"ui.hdll" },
			{ lib:"heaps", f:"uv.hdll" },
			{ lib:"heaps", f:"libuv.1.dylib" },
			{ lib:"heaps", f:"openal.hdll" },
			{ lib:"heaps", f:"libopenal.1.dylib" },

			{ lib:"hlsteam", f:"steam.hdll" },
			{ lib:"hlsteam", f:"libsteam_api.dylib" },
		],
	}

	var linuxFiles: Target.RuntimeFiles = {
		platform: Linux,
        dir: 'dist_files/hl_linux/',
		files: [
			// HashLink binary
			{ f:"hl", format:"$.x64" },
			{ f:"run.sh" },
			{ f:"libhl.so" },
			{ f:"gamecontrollerdb.txt" },
			{ f:"mysql.hdll" },

			{ f:"ssl.hdll" },
			{ f:"libmbedtls.so.14" },
			{ f:"libmbedx509.so.1" },
			{ f:"libmbedcrypto.so.7" },

			// FMT
			{ lib:"heaps", f:"fmt.hdll" },
			{ lib:"heaps", f:"libpng16.so.16" },
			{ lib:"heaps", f:"libturbojpeg.so.0" }, 
			{ lib:"heaps", f:"libvorbisfile.so.3" },
			{ lib:"heaps", f:"libvorbis.so.0" },
			{ lib:"heaps", f:"libogg.so.0" },
			{ lib:"heaps", f:"libz.so.1" },

			// openAL
			{ lib:"heaps", f:"openal.hdll" },
			{ lib:"heaps", f:"libopenal.so.1" },

			// UI
			{ lib:"heaps", f:"ui.hdll" },

			// UV
			{ lib:"heaps", f:"uv.hdll" },
			{ lib:"heaps", f:"libuv.so.1" },

			// SDL
			{ lib:"hlsdl", f:"sdl.hdll" },
			{ lib:"hlsdl", f:"libSDL2-2.0.so.0" },
			{ lib:"hlsdl", f:"libsndio.so.7" },

			// Steam
			{ lib:"hlsteam", f:"steam.hdll" },
            { lib:"hlsteam", f:"libsteam_api.so" },
		],
	}
}