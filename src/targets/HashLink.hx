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
			var packageDir = '$outputDir/hl_win/$projName';

			createPackage(hxmlContent, packageDir, winFiles);

			Term.print('Setting exe icon...');
			runTool('rcedit.exe', ['$packageDir/$projName.exe', '--set-icon "$projDir/$projName.ico"']);

			// for steam, grab the appid
			if(hxmlRequiresLib(hxmlContent, 'hlsteam') && FileSystem.exists('$projDir/steam_appid.txt')) {
				FileUtil.copyFile('$projDir/steam_appid.txt', '$packageDir/steam_appid.txt');
			}

			FileUtil.zipFolder('$outputDir/${projName}_hl_win_itch.zip', '$outputDir/hl_win/');
			FileUtil.zipFolder('$outputDir/${projName}_hl_win_steam.zip', '$packageDir/');
		} 
		// LINUX
		else if(Sys.systemName() == 'Linux') {
			var packageDir = '$outputDir/hl_linux/$projName';

			createPackage(hxmlContent, packageDir, linuxFiles);
			
			Term.print("Updating the linux files with execute permissions...");
			Sys.command('chmod', ['+x', '$packageDir/$projName.x64']);
			Sys.command('chmod', ['+x', '$packageDir/run.sh']);

			// for steam, grab the appid
			if(hxmlRequiresLib(hxmlContent, 'hlsteam') && FileSystem.exists('$projDir/steam_appid.txt')) {
				FileUtil.copyFile('$projDir/steam_appid.txt', '$packageDir/steam_appid.txt');
			}

			FileUtil.zipFolder('$outputDir/${projName}_hl_linux_itch.zip', '$outputDir/hl_linux/');
			FileUtil.zipFolder('$outputDir/${projName}_hl_linux_steam.zip', '$outputDir/hl_linux/$projName/');
		} 
		// MAC
		else if(Sys.systemName() == 'Mac') {
			var packageDir = '$outputDir/hl_mac/$projName';

			createPackage(hxmlContent, packageDir, macFiles);
			
			Term.print("Updating the mac files with execute permissions...");
			Sys.command('chmod', ['+x', '$packageDir/$projName']);
			
			// for steam, grab the appid
			if(hxmlRequiresLib(hxmlContent, 'hlsteam') && FileSystem.exists('$projDir/steam_appid.txt')) {
				FileUtil.copyFile('$projDir/steam_appid.txt', '$packageDir/steam_appid.txt');
			}
			
			FileUtil.zipFolder(outputDir + '/${projName}_hl_mac_itch.zip', '$outputDir/hl_mac/');
			FileUtil.zipFolder(outputDir + '/${projName}_hl_mac_steam.zip', '$outputDir/hl_mac/$projName/');
			
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
		
		// WINDOWS
		if(Sys.systemName() == 'Windows') {
			FileUtil.copyFile(out, '$packageDir/hlboot.dat');
		}
		// LINUX
		else if(Sys.systemName() == 'Linux') {
			var runScript = sys.io.File.getContent('$packageDir/run.sh');
			runScript = StringTools.replace(runScript, "$PROJ_NAME", projName);
			sys.io.File.saveContent(packageDir + 'run.sh', runScript);
	
			FileUtil.copyFile(out, '$packageDir/hlboot.dat');
		}
		// MAC
		else if(Sys.systemName() == 'Mac') {
			FileUtil.copyFile(out, '$packageDir/hlboot.dat');
			
			// Term.print("Updating Info.plist with project variables...");
			// var infoData = sys.io.File.getContent('$packageDir/Contents/Info.plist');
			// infoData = StringTools.replace(infoData, "$PROJ_NAME", projName);
			// sys.io.File.saveContent('$packageDir/Contents/Info.plist', infoData);
			
			// Term.print("Setting the icon for the app bundle...");
			// if(sys.FileSystem.exists('${projDir}/${projName}.icns')) {
			// 	FileUtil.copyFile('$projDir/$projName.icns', '$packageDir/Contents/Resources/$projName.icns');
			// }
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
			{ f:"fmt.hdll" },
			{ f:"ssl.hdll" },
			{ f:"mysql.hdll" },
			{ f:"hlimgui.hdll", lib:"hlimgui" },
			{ f:"sdl.hdll", lib:"hlsdl" },
			{ f:"directx.hdll", lib:"hldx" },
			{ f:"steam.hdll", lib:"hlsteam" },
			{ f:"openal.hdll", lib:"heaps" },
			{ f:"ui.hdll", lib:"heaps" },
			{ f:"uv.hdll", lib:"heaps" },

			{ f:"hl.exe", format:"$.exe" },
			{ f:"libhl.dll" },
			{ f:"msvcr120.dll" },
			{ f:"msvcp120.dll" },
			{ f:"libmbedcrypto.dll" },
			{ f:"libmbedtls.dll" },
			{ f:"libmbedx509.dll" },
			{ f:"libpcre-1.dll" },
			{ f:"zlib1.dll" },
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
			{ f:"mysql.hdll" },

			{ f:"ssl.hdll" },
			{ f:"libmbedtls.so.10" },
			{ f:"libmbedx509.so.0" },
			{ f:"libmbedcrypto.so.0" },

			// FMT
			{ lib:"heaps", f:"fmt.hdll" },
			{ lib:"heaps", f:"libpng16.so.16" },
			{ lib:"heaps", f:"libturbojpeg.so.0" }, 
			{ lib:"heaps", f:"libvorbisfile.so.3" },
			{ lib:"heaps", f:"libvorbis.so.0" },
			{ lib:"heaps", f:"libogg.so.0" },

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
			{ lib:"hlsdl", f:"libsndio.so.6.1" },

			// Steam
			{ lib:"hlsteam", f:"steam.hdll" },
            { lib:"hlsteam", f:"libsteam_api.so" },


			
			// { f:"libbsd.so.0" },
			// { f:"libmbedcrypto.so" },
			// { f:"libmbedcrypto.so.2.2.1" },
			// { f:"libmbedtls.so" },
			// { f:"libmbedtls.so.2.2.1" },
			// { f:"libmbedx509.so" },
			// { f:"libmbedx509.so.2.2.1" },
			// { f:"libsndio.so" },
			
			// { f:"libSDL2-2.0.so", lib:"hlsdl" },
			// { f:"libSDL2-2.0.so.0.4.0", lib:"hlsdl" },
			// { f:"libSDL2.so", lib:"hlsdl" },
			
		],
	}
}