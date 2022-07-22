package targets;

import Target.Platform;

class HashLink extends Target {
    public function new(dd:String, pd: String, pn:String) {
        super(dd, pd, pn);
    }

    public override function compile(hxml:String, outputDir:String) {
        if(Sys.command("haxe", [hxml]) != 0)
			Term.error('Compilation failed!');

        var hxmlContent = Target.parseHxml(projDir, hxml);

        createPackage(hxmlContent, outputDir + "/hl_win/", winFiles);
        createPackage(hxmlContent, outputDir + "/hl_mac/", macFiles);
        createPackage(hxmlContent, outputDir + "/hl_linux/", linuxFiles);

		if(Sys.systemName() != 'Windows') {
			Term.print("Updated the mac and linux files with execute permissions...");
			Sys.command('chmod', ['+x', outputDir + '/hl_mac/' + projName]);
			Sys.command('chmod', ['+x', outputDir + '/hl_linux/' + projName]);
		}

		FileUtil.zipFolder(outputDir + '/${projName}_hl_win.zip', outputDir + "/hl_win");
		FileUtil.zipFolder(outputDir + '/${projName}_hl_mac.zip', outputDir + "/hl_mac");
		FileUtil.zipFolder(outputDir + '/${projName}_hl_linux.zip', outputDir + "/hl_linux");

		if(Sys.systemName() == 'Windows') {
			Term.print('Updating execute permissions on Mac/Linux zip files...');
			runTool('zip_exec.exe', [outputDir + '/${projName}_hl_mac.zip', projName]);
			runTool('zip_exec.exe', [outputDir + '/${projName}_hl_linux.zip', projName]);
		}
	}

    function createPackage(hxml:Array<String>, packageDir:String, files:Target.RuntimeFiles) {
		Term.print("Packaging " + packageDir + "...");
		FileUtil.createDirectory(packageDir);

		// Runtimes
		// var fileList = commonFiles.files.concat(files);
		copyRuntimeFiles(hxml, packageDir, files);

		// Copy HL bin file
		var out = getHxmlParam(hxml, "-hl");
		FileUtil.copyFile(out, packageDir + "/hlboot.dat");
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
			{ f:"sdl.hdll", lib:"hlsdl" },
			{ f:"steam.hdll", lib:"hlsteam" },
			{ f:"openal.hdll", lib:"heaps" },
			{ f:"ui.hdll", lib:"heaps" },
			{ f:"uv.hdll", lib:"heaps" },

			{ f:"hl.exe", format:"$.exe" },
			{ f:"libhl.dll" },
			{ f:"msvcr120.dll" },
			{ f:"msvcp120.dll" },
			{ f:"OpenAL32.dll", lib:"heaps" },
			{ f:"SDL2.dll", lib:"hlsdl" },
			{ f:"steam_api64.dll", lib:"hlsteam" },
		],
	}

	var macFiles: Target.RuntimeFiles = {
		platform: Mac,
        dir: 'dist_files/hl_mac/',
		files: [
			// common
			{ f:"fmt.hdll" },
			{ f:"ssl.hdll" },
			{ f:"mysql.hdll" },
			{ f:"sdl.hdll", lib:"hlsdl" },
			{ f:"steam.hdll", lib:"hlsteam" },
			{ f:"openal.hdll", lib:"heaps" },
			{ f:"ui.hdll", lib:"heaps" },
			{ f:"uv.hdll", lib:"heaps" },

			{ f:"hl", format:"$" },
			{ f:"libhl.dylib" },
			{ f:"libpng16.16.dylib" }, // fmt
			{ f:"libvorbis.0.dylib" }, // fmt
			{ f:"libvorbisfile.3.dylib" }, // fmt
			{ f:"libmbedtls.10.dylib" }, // SSL
			{ f:"libuv.1.dylib", lib:"heaps" },
			{ f:"libopenal.1.dylib", lib:"heaps" },
			{ f:"libSDL2-2.0.0.dylib", lib:"hlsdl" },
		],
	}

	var linuxFiles: Target.RuntimeFiles = {
		platform: Linux,
        dir: 'dist_files/hl_linux/',
		files: [
			// common
			{ f:"fmt.hdll" },
			{ f:"ssl.hdll" },
			{ f:"mysql.hdll" },
			{ f:"sdl.hdll", lib:"hlsdl" },
			{ f:"steam.hdll", lib:"hlsteam" },
			{ f:"openal.hdll", lib:"heaps" },
			{ f:"ui.hdll", lib:"heaps" },
			{ f:"uv.hdll", lib:"heaps" },

			{ f:"hl", format:"$" },
			{ f:"libbsd.so.0" },
			{ f:"libhl.so" },
			{ f:"libmbedcrypto.so" },
			{ f:"libmbedcrypto.so.0" },
			{ f:"libmbedcrypto.so.2.2.1" },
			{ f:"libmbedtls.so" },
			{ f:"libmbedtls.so.10" },
			{ f:"libmbedtls.so.2.2.1" },
			{ f:"libmbedx509.so" },
			{ f:"libmbedx509.so.0" },
			{ f:"libmbedx509.so.2.2.1" },
			{ f:"libogg.so.0" },
			{ f:"libopenal.so.1" },
			{ f:"libpng16.so.16" },
			{ f:"libsndio.so" },
			{ f:"libsndio.so.6.1" },

			{ f:"libturbojpeg.so.0" },
			{ f:"libuv.so.1" },
			{ f:"libvorbis.so.0" },
			{ f:"libvorbisfile.so.3" },

			{ f:"libSDL2-2.0.so", lib:"hlsdl" },
			{ f:"libSDL2-2.0.so.0", lib:"hlsdl" },
			{ f:"libSDL2-2.0.so.0.4.0", lib:"hlsdl" },
			{ f:"libSDL2.so", lib:"hlsdl" },

            { f:"libsteam_api.so", lib:"hlsteam" },
		],
	}
}