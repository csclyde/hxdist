# hxdist

Packages Haxe applications for Windows, macOS, Linux, and the web.

## Install

```sh
haxelib git hxdist https://github.com/csclyde/hxdist.git
```

## Usage

```sh
haxelib run hxdist [options] <hxml1> [<hxml2> ...]
```

Each HXML must contain either `-hl` or `-js`.

```text
-o <dir>       Output directory; default: dist/
-p <name>      Project/package name; default: project folder name
-icon <base>   Windows HashLink icon base path
-v             Verbose output
-h             Show help
```

The output directory is cleared before each run. Archives are created
automatically.

## Windows icons

Set an icon base path with `-icon` or the `icon` field in the project-root
`hxdist.json`:

```json
{
  "icon": "meta/MyGame",
  "searchPaths": ["native", "../shared-runtime"],
  "include": ["native/my_runtime.hdll", "native/my_runtime.dll"],
  "exclude": []
}
```

Paths are relative to the project root. For `meta/MyGame`, hxdist searches for
`meta/MyGame_<size>.png` files, such as `_16.png` and `_256.png`. If none are
found, it uses `meta/MyGame.ico`. Without configuration, the default base is
`meta/<projectName>`. PNGs take precedence over `.ico` files.

## HashLink native dependencies

hxdist reads the compiled `.hl` file, finds required HDLLs, and recursively
packages their native dependencies. It searches the active HashLink/Haxelib
installation and the project directory; no library allowlist is required.

For libraries loaded dynamically, add the corresponding fields to that file.
Paths are relative to the project root. `searchPaths` adds search locations,
`include` adds files that bytecode inspection cannot find, and `exclude` skips
dependencies. Missing required files and destination conflicts fail the build.

After discovery, the console shows a tree of packaged native dependencies with
their source paths. Root entries show whether they came from the HashLink
runtime, bytecode native libraries, or `hxdist.json` inclusions. Shared dependencies
appear under each parent, with `(already shown)` preventing repeated expansion
and cycles. System files and configured exclusions stay outside the package tree.

For Steam, include its library in the HXML. If Steam is detected, hxdist copies
`meta/steam_appid.txt`. Point the Linux Steam launch configuration to `run.sh`.

## Support

If hxdist is useful to you, you can support its development:
[Donate on Ko-fi](https://ko-fi.com/c_l_y_d_e)
