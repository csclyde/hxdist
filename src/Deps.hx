
typedef RuntimeFiles = {
	var platform: Platform;
	var files:Array<RuntimeFile>;
}

typedef RuntimeFile = {
	var ?lib: Null<String>;
	var f: String; // defaults to 64bits version
	var ?executableFormat: String;
}

enum Platform {
	Windows;
	Mac;
	Linux;
}

class Deps {

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
			{ lib:"hlsteam", f:"steam_api64.dll" },

			{ lib:"hldx", f:"directx.hdll" },
			{ lib:"hldx", f:"d3dcompiler_47.dll" },
		],
	}

	public static var HL_RUNTIME_FILES_MAC: RuntimeFiles = {
		platform: Mac,
		files: [
			{ f:"dist_files/hl_mac/hl", executableFormat:"$" },
			{ f:"dist_files/hl_mac/libhl.dylib" },
			{ f:"dist_files/hl_mac/libpng16.16.dylib" }, // fmt
			{ f:"dist_files/hl_mac/libvorbis.0.dylib" }, // fmt
			{ f:"dist_files/hl_mac/libvorbisfile.3.dylib" }, // fmt
			{ f:"dist_files/hl_mac/libmbedtls.10.dylib" }, // SSL

			{ lib:"heaps", f:"dist_files/hl_mac/libuv.1.dylib" },
			{ lib:"heaps", f:"dist_files/hl_mac/libopenal.1.dylib" },

			{ lib:"hlsdl", f:"dist_files/hl_mac/libSDL2-2.0.0.dylib" },
		],
	}

	public static var HL_RUNTIME_FILES_LINUX: RuntimeFiles = {
		platform: Linux,
		files: [
			{ f:"dist_files/hl_linux/hl", executableFormat:"$" },
			{ f:"dist_files/hl_linux/fmt.hdll" },
			{ f:"dist_files/hl_linux/mysql.hdll" },
			{ f:"dist_files/hl_linux/sdl.hdll" },
			{ f:"dist_files/hl_linux/ssl.hdll" },

			{ f:"dist_files/hl_linux/libbsd.so.0" },
			{ f:"dist_files/hl_linux/libhl.so" },
			{ f:"dist_files/hl_linux/libmbedcrypto.so" },
			{ f:"dist_files/hl_linux/libmbedcrypto.so.0" },
			{ f:"dist_files/hl_linux/libmbedcrypto.so.2.2.1" },
			{ f:"dist_files/hl_linux/libmbedtls.so" },
			{ f:"dist_files/hl_linux/libmbedtls.so.10" },
			{ f:"dist_files/hl_linux/libmbedtls.so.2.2.1" },
			{ f:"dist_files/hl_linux/libmbedx509.so" },
			{ f:"dist_files/hl_linux/libmbedx509.so.0" },
			{ f:"dist_files/hl_linux/libmbedx509.so.2.2.1" },
			{ f:"dist_files/hl_linux/libogg.so.0" },
			{ f:"dist_files/hl_linux/libopenal.so.1" },
			{ f:"dist_files/hl_linux/libpng16.so.16" },
			{ f:"dist_files/hl_linux/libSDL2-2.0.so" },
			{ f:"dist_files/hl_linux/libSDL2-2.0.so.0" },
			{ f:"dist_files/hl_linux/libSDL2-2.0.so.0.4.0" },
			{ f:"dist_files/hl_linux/libSDL2.so" },
			{ f:"dist_files/hl_linux/libsndio.so" },
			{ f:"dist_files/hl_linux/libsndio.so.6.1" },
			
            { f:"dist_files/hl_linux/libsteam_api.so" },
			{ f:"dist_files/hl_linux/libturbojpeg.so.0" },
			{ f:"dist_files/hl_linux/libuv.so.1" },
			{ f:"dist_files/hl_linux/libvorbis.so.0" },
			{ f:"dist_files/hl_linux/libvorbisfile.so.3" },

			{ lib:"heaps", f:"dist_files/hl_linux/openal.hdll" },
			{ lib:"heaps", f:"dist_files/hl_linux/ui.hdll" },
			{ lib:"heaps", f:"dist_files/hl_linux/uv.hdll" },

			{ lib:"hlsteam", f:"dist_files/hl_linux/steam.hdll" },
		],
	}
}
