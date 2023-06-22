# About

A program to package Haxe applications for distribution. 

- Thanks to Sébastien Bénard for redistHelper, which this tool is based off of (https://github.com/deepnight/redistHelper).

# Targets

## Current Targets

- HashLink bytecode: Windows, Mac, Linux
- JavaScript: Web

## Current Libraries

- Heaps.io
- SDL
- DirectX
- hlsteam
- hlimgui

## Future Targets

- HashLink/C compiled executable: Windows, Mac
- OpenFL
- HaxeFlixel

# Install

```
haxelib git hxdist git@github.com:csclyde/hxdist.git
```

## Usage
If you want your Windows app to have an icon, include a .ico file with the same name as your project in a /meta folder at the top level (next to the .hxml). Same for Mac, except it excepts a .icns file.

For Steam/HLImGui, make sure your hxml file contains "-lib hlsteam" or "-lib hlimgui". If so, the tool will package up the Steam hdll and dynamic library in your package. It will also look for a steam_appid.txt in your /meta folder, and include that with the bundle.

When distributing to steam, make sure your Linux run config points at the run.sh file, not at the executable itself. Otherwise it won't work.

```
USAGE:
    haxelib run hxdist [<hxml>]
FLAGS:
    -h Show tool usage
    -v Verbose output
EXAMPLES:
    haxelib run hxdist hashlink.hxml
```
