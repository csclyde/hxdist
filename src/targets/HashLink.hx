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
			createPackage(hxmlContent, outputDir + '/hl_win/${projName}/', winFiles);

			Term.print('Setting exe icon...');
			runTool('rcedit.exe', [outputDir + '/hl_win/$projName/${projName}.exe', '--set-icon "${projDir}/${projName}.ico"']);

			FileUtil.zipFolder(outputDir + '/${projName}_hl_win_itch.zip', '$outputDir/hl_win/');
			FileUtil.zipFolder(outputDir + '/${projName}_hl_win_steam.zip', '$outputDir/hl_win/$projName/');
		} 
		// LINUX
		else if(Sys.systemName() == 'Linux') {
			createPackage(hxmlContent, outputDir + '/hl_linux/${projName}/', linuxFiles);
			
			Term.print("Updating the linux files with execute permissions...");
			Sys.command('chmod', ['+x', outputDir + '/hl_linux/${projName}/$projName.x64']);

			FileUtil.zipFolder(outputDir + '/${projName}_hl_linux_itch.zip', '$outputDir/hl_linux/');
			FileUtil.zipFolder(outputDir + '/${projName}_hl_linux_steam.zip', '$outputDir/hl_linux/$projName/');
		} 
		// MAC
		else if(Sys.systemName() == 'Mac') {
			createPackage(hxmlContent, outputDir + '/hl_mac/${projName}/$projName.app/', macFiles);
			
			Term.print("Updating the mac files with execute permissions...");
			Sys.command('chmod', ['+x', outputDir + '/hl_mac/${projName}/$projName.app/Contents/MacOS/' + projName]);

			FileUtil.zipFolder(outputDir + '/${projName}_hl_mac_itch.zip', '$outputDir/hl_mac/');
			FileUtil.zipFolder(outputDir + '/${projName}_hl_mac_steam.zip', '$outputDir/hl_mac/$projName/');
		}
	}

    function createPackage(hxml:Array<String>, packageDir:String, files:Target.RuntimeFiles) {
		Term.print("Packaging " + packageDir + "...");
		FileUtil.createDirectory(packageDir);

		copyRuntimeFiles(hxml, packageDir, files);
		
		// Copy HL bin file
		var out = getHxmlParam(hxml, "-hl");
		
		// we need some special junk done on mac
		if(files == macFiles) {
			FileUtil.copyFile(out, packageDir + 'Contents/MacOS/hlboot.dat');

			Term.print("Updating Info.plist with project variables...");
			var infoData = sys.io.File.getContent(packageDir + 'Contents/Info.plist');
			infoData = StringTools.replace(infoData, "$PROJ_NAME", projName);
			sys.io.File.saveContent(packageDir + 'Contents/Info.plist', infoData);
		} else {
			FileUtil.copyFile(out, packageDir + "/hlboot.dat");
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
			{ f:"hl", format:"$", d: "Contents/MacOS/"},
			{ f:"Info.plist", d: "Contents/" },
			{ f:"libhl.dylib", d: "Contents/MacOS/" },
			{ f:"mysql.hdll", d: "Contents/MacOS/" },

			{ f:"fmt.hdll", d: "Contents/MacOS/" },
			{ f:"libpng16.16.dylib", d: "Contents/MacOS/" },
			{ f:"libvorbis.0.dylib", d: "Contents/MacOS/" },
			{ f:"libvorbisfile.3.dylib", d: "Contents/MacOS/" },

			{ f:"ssl.hdll", d: "Contents/MacOS/" },
			{ f:"libmbedtls.10.dylib", d: "Contents/MacOS/" },

			{ lib:"hlsdl", f:"sdl.hdll", d: "Contents/MacOS/" },
			{ lib:"hlsdl", f:"libSDL2-2.0.0.dylib", d: "Contents/MacOS/" },
			
			{ lib:"heaps", f:"ui.hdll", d: "Contents/MacOS/" },
			{ lib:"heaps", f:"uv.hdll", d: "Contents/MacOS/" },
			{ lib:"heaps", f:"openal.hdll", d: "Contents/MacOS/" },
			{ lib:"heaps", f:"libuv.1.dylib", d: "Contents/MacOS/" },
			{ lib:"heaps", f:"libopenal.1.dylib", d: "Contents/MacOS/" },

			{ lib:"hlsteam", f:"steam.hdll", d: "Contents/MacOS/" },
		],
	}

	var linuxFiles: Target.RuntimeFiles = {
		platform: Linux,
        dir: 'dist_files/hl_linux/',
		files: [
			// HashLink binary
			{ f:"hl", format:"$.x64" },
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