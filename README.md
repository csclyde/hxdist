# About

A program to package Haxe applications for distribution. Based off of redistHelper by Sébastien Bénard (https://github.com/deepnight/redistHelper).

For now, hxdist only targets HashLink apps. For those, it will create Win/Mac/Linux packages with all the required library files, the HashLink executable, and a build of the project. I set it up so that additional targets should be easy to add in the future. Feel free to request them, or create a PR for them if you can.

# Install

```
haxelib install hxdist
```

Or, a development version can be installed from github:

```
haxelib git hxdist https://github.com/csclyde/hxdist.git
```

## Usage

```
USAGE:
    haxelib run hxdist [<hxml1>] [<hxml2>] [<hxml3>]
FLAGS:
    -h Show tool usage
    -v Verbose output
    -z Create .zip files for each platform
    -win Build for Windows
    -mac Build for MacOS
    -linux Build for Linux
PARAMS:
    [-p <project_name>] Defaults to the project folder name
    [-o <output_dir>] Defaults to /dist within your project folder
EXAMPLES:
    haxelib run hxdist -mac hashlink.hxml -o someFolder -p MyGreatGame
    haxelib run hxdist -win -mac -linux -z hashlink.hxml flash.hxml webgl.hxml
```
