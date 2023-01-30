# About

A program to package Haxe applications for distribution. 

- Thanks to Sébastien Bénard for redistHelper, which this tool is based off of (https://github.com/deepnight/redistHelper).

# Targets

## Current Targets

- HashLink bytecode: Windows, Mac, Linux
- HashLink/C compiled executable: Windows, Linux
- JavaScript: Web

## Current Libraries

- Heaps.io
- SDL
- DirectX
- Steam API
- HLImGui

## Future Targets

- HashLink/C compiled executable: Windows, Mac
- OpenFL
- HaxeFlixel

# Install

```
haxelib install hxdist
```

## Usage
If you want your Windows app to have an icon, include a .ico file with the same name as your project in the top level (next to the .hxml). Same for Mac, except it excepts a .icns file.

For Steam/HLImGui, make sure your hxml file is including "-lib hlsteam". If so, the tool will package up the Steam hdll and dynamic library in your package. It will also look for a steam_appid.txt in your top level project folder, and include that with the bundle.

```
USAGE:
    haxelib run hxdist [<hxml>]
FLAGS:
    -h Show tool usage
    -v Verbose output
EXAMPLES:
    haxelib run hxdist hashlink.hxml
```
