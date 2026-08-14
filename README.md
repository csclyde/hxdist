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

# Install

```
haxelib git hxdist git@github.com:csclyde/hxdist.git
```

## Usage
If you want your Windows app to have an icon, include a .ico file with the same name as your project in a /meta folder at the top level (next to the .hxml). Same for Mac, except it excepts a .icns file.

For Steam/HLImGui, use the corresponding library in your HXML. hxdist reads
the resulting HashLink bytecode and packages the required HDLL and native
library automatically. It also looks for a steam_appid.txt in your /meta
folder when Steam is detected.

When distributing to steam, make sure your Linux run config points at the run.sh file, not at the executable itself. Otherwise it won't work.

Windows HashLink packages are converted to the GUI subsystem automatically, so they do not open a console window. hxdist edits the packaged PE header directly and does not require `editbin`. `rcedit` is only used when an icon is provided.

```
USAGE:
    haxelib run hxdist [<hxml>]
FLAGS:
    -h Show tool usage
    -v Verbose output
EXAMPLES:
    haxelib run hxdist hashlink.hxml
```

## HashLink native dependencies

For HashLink bytecode builds, hxdist determines native dependencies from the
compiled `.hl` file. It reads the native library table, finds the matching
`.hdll` files in the active HashLink/Haxelib installation, and recursively
collects their platform dependencies (`.dll`, `.so`, or `.dylib`). The old
per-library runtime list and bundled runtime directory are no longer needed.

If a library loads native files dynamically at runtime, add an optional
`hxdist.json` beside the project HXML:

```json
{
  "searchPaths": ["native", "../shared-runtime"],
  "include": ["native/my_runtime.hdll", "native/my_runtime.dll"],
  "exclude": []
}
```

Paths are relative to the project directory. `searchPaths` are searched for
HDLLs and transitive native dependencies. `include` is for files that cannot
be discovered from the compiled bytecode, such as plugins loaded by a file
name at runtime. Unresolved required libraries and conflicting destination
file names fail the build; normal operating-system libraries are reported and
left to the target system.
