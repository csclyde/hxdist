# Regression checks

Run from the repository root:

```powershell
haxe build.hxml
haxe -cp src -cp tools/tests -main NativeDependencyTreeTest --interp
haxe -cp src -cp tools/tests -main PackagingRegressionTest --interp
powershell -NoProfile -ExecutionPolicy Bypass -File tools/tests/WindowsSmokeTest.ps1
```

The Haxe tests cover dependency hierarchy, shared references and cycles, output
directory guards, archive names and payloads, native configuration validation,
PE and ELF bounds, required/optional imports, and PE checksums. Fixtures are
written under the ignored `bin/` directory.

The Windows smoke test packages real JavaScript and HashLink builds, embeds the
repository icon, and checks that invalid inputs preserve the previous archive.
When Git's shell is installed, it also runs the Linux launcher with spaces in
paths and arguments, an existing library path, and a nonzero child exit code.
Native macOS and Linux packaging still require verification on those systems.
