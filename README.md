# About

A program to package Haxe applications for distribution. 

- Thanks to Sébastien Bénard for redistHelper, which this tool is based off of (https://github.com/deepnight/redistHelper).
- Thanks to Ronnie Hedlund for making a tool to give Linux/Mac zip files the correct execute permissions (https://sourceforge.net/p/galaxyv2/code/HEAD/tree/other/zip_exec/zip_exec.cpp)

# Targets

## Current Targets

- HashLink bytecode: Windows, Mac, Linux
- HashLink/C compiled executable: Linux
- JavaScript: Web

## Current Libraries

- Heaps.io
- SDL

## Future Targets

- HashLink/C compiled executable: Windows, Mac
- HashLink/C cross compilation from all platforms to all platforms
- OpenFL
- HaxeFlixel

# Install

```
haxelib install hxdist
```

## Usage

```
USAGE:
    haxelib run hxdist [<hxml1>] [<hxml2>] [<hxml3>]
FLAGS:
    -h Show tool usage
    -v Verbose output
PARAMS:
    [-p <project_name>] Defaults to the project folder name
    [-o <output_dir>] Defaults to /dist within your project folder
EXAMPLES:
    haxelib run hxdist hashlink.hxml -o someFolder -p MyGreatGame
```