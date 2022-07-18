
typedef RuntimeFiles = {
	var platform: Platform;
	var files:Array<RuntimeFile>;
}

typedef RuntimeFile = {
	var ?lib: Null<String>;
	var f: String; // defaults to 64bits version
	var ?f32: String; // alternative 32bits version
	var ?executableFormat: String;
}

typedef ExtraCopiedFile = {
	var source : FilePath;
	var isDir : Bool;
	var rename: Null<String>;
}

enum Platform {
	Windows;
	Macos;
	Linux;
}

class Deps {
    public static var NEKO_RUNTIME_FILES_WIN : RuntimeFiles = {
		platform: Windows,
		files: [
			{ f:"neko.lib" },

			{ f:"concrt140.dll" },
			{ f:"gcmt-dll.dll" },
			{ f:"msvcp140.dll" },
			{ f:"neko.dll" },
			{ f:"vcruntime140.dll" },

			{ f:"mysql.ndll" },
			{ f:"mysql5.ndll" },
			{ f:"regexp.ndll" },
			{ f:"sqlite.ndll" },
			{ f:"ssl.ndll" },
			{ f:"std.ndll" },
			{ f:"ui.ndll" },
			{ f:"zlib.ndll" },
		],
	}

	public static var HL_RUNTIME_FILES_WIN : RuntimeFiles = {
		platform: Windows,
		files: [
			{ f:"hl.exe", executableFormat:"$.exe" },
			{ f:"libhl.dll" },
			{ f:"msvcr120.dll" },
			{ f:"msvcp120.dll" },
			{ f:"fmt.hdll" },
			{ f:"ssl.hdll" },

			{ lib:"heaps", f:"OpenAL32.dll" },
			{ lib:"heaps", f:"openal.hdll" },
			{ lib:"heaps", f:"ui.hdll" },
			{ lib:"heaps", f:"uv.hdll" },

			{ lib:"hlsdl", f:"SDL2.dll" },
			{ lib:"hlsdl", f:"sdl.hdll" },

			{ lib:"hlsteam", f:"steam.hdll" },
			{ lib:"hlsteam", f:"steam_api64.dll", f32:"steam_api.dll" },

			{ lib:"hldx", f:"directx.hdll" },
			{ lib:"hldx", f:"d3dcompiler_47.dll" },
		],
	}

	public static var HL_RUNTIME_FILES_MAC: RuntimeFiles = {
		platform: Macos,
		files: [
			{ f:"redistFiles/mac/hl", executableFormat:"$" },
			{ f:"redistFiles/mac/libhl.dylib" },
			{ f:"redistFiles/mac/libpng16.16.dylib" }, // fmt
			{ f:"redistFiles/mac/libvorbis.0.dylib" }, // fmt
			{ f:"redistFiles/mac/libvorbisfile.3.dylib" }, // fmt
			{ f:"redistFiles/mac/libmbedtls.10.dylib" }, // SSL

			{ lib:"heaps", f:"redistFiles/mac/libuv.1.dylib" },
			{ lib:"heaps", f:"redistFiles/mac/libopenal.1.dylib" },

			{ lib:"hlsdl", f:"redistFiles/mac/libSDL2-2.0.0.dylib" },
		],
	}

	public static var HL_RUNTIME_FILES_LINUX: RuntimeFiles = {
		platform: Linux,
		files: [
			{ f:"redistFiles/hl_linux/hl", executableFormat:"$" },
			{ f:"redistFiles/hl_linux/fmt.hdll" },
			{ f:"redistFiles/hl_linux/mysql.hdll" },
			{ f:"redistFiles/hl_linux/sdl.hdll" },
			{ f:"redistFiles/hl_linux/ssl.hdll" },

			{ f:"redistFiles/hl_linux/libbsd.so.0" },
			{ f:"redistFiles/hl_linux/libhl.so" },
			{ f:"redistFiles/hl_linux/libmbedcrypto.so" },
			{ f:"redistFiles/hl_linux/libmbedcrypto.so.0" },
			{ f:"redistFiles/hl_linux/libmbedcrypto.so.2.2.1" },
			{ f:"redistFiles/hl_linux/libmbedtls.so" },
			{ f:"redistFiles/hl_linux/libmbedtls.so.10" },
			{ f:"redistFiles/hl_linux/libmbedtls.so.2.2.1" },
			{ f:"redistFiles/hl_linux/libmbedx509.so" },
			{ f:"redistFiles/hl_linux/libmbedx509.so.0" },
			{ f:"redistFiles/hl_linux/libmbedx509.so.2.2.1" },
			{ f:"redistFiles/hl_linux/libogg.so.0" },
			{ f:"redistFiles/hl_linux/libopenal.so.1" },
			{ f:"redistFiles/hl_linux/libpng16.so.16" },
			{ f:"redistFiles/hl_linux/libSDL2-2.0.so" },
			{ f:"redistFiles/hl_linux/libSDL2-2.0.so.0" },
			{ f:"redistFiles/hl_linux/libSDL2-2.0.so.0.4.0" },
			{ f:"redistFiles/hl_linux/libSDL2.so" },
			{ f:"redistFiles/hl_linux/libsndio.so" },
			{ f:"redistFiles/hl_linux/libsndio.so.6.1" },
			
            { f:"redistFiles/hl_linux/libsteam_api.so" },
			{ f:"redistFiles/hl_linux/libturbojpeg.so.0" },
			{ f:"redistFiles/hl_linux/libuv.so.1" },
			{ f:"redistFiles/hl_linux/libvorbis.so.0" },
			{ f:"redistFiles/hl_linux/libvorbisfile.so.3" },

			{ lib:"heaps", f:"redistFiles/hl_linux/openal.hdll" },
			{ lib:"heaps", f:"redistFiles/hl_linux/ui.hdll" },
			{ lib:"heaps", f:"redistFiles/hl_linux/uv.hdll" },

			{ lib:"hlsteam", f:"redistFiles/hl_linux/steam.hdll" },
		],
	}

    public static var SWF_RUNTIME_FILES_WIN : RuntimeFiles = {
		platform: Windows,
		files: [
			{ lib:null, f:"redistFiles/flash/win_flashplayer_32_sa.exe", executableFormat:"flashPlayer.bin" },
		],
	}
}