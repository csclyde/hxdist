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
For a Windows HashLink app icon, hxdist accepts an icon base path from the
`-icon` CLI option or the `icon` field in `hxdist.json`. Paths are relative to
the project directory. For example:

```json
{
  "icon": "meta/MyGame"
}
```

With that base, hxdist searches for `meta/MyGame_8.png`,
`meta/MyGame_16.png`, `meta/MyGame_32.png`, and any other numeric PNG sizes.
If no PNG set is found, it falls back to `meta/MyGame.ico`. PNG sets take
precedence when both forms exist. Without configuration, the default base is
`meta/<projectName>`.

For Steam/HLImGui, use the corresponding library in your HXML. hxdist reads
the resulting HashLink bytecode and packages the required HDLL and native
library automatically. It also looks for a steam_appid.txt in your /meta
folder when Steam is detected.

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

## Support

If hxdist is useful to you, you can support its development:

[Donate on Ko-fi](https://ko-fi.com/c_l_y_d_e)
