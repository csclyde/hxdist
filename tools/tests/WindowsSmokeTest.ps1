$ErrorActionPreference = 'Stop'
$repoDir = (Get-Location).Path
$fixtureDir = Join-Path $repoDir 'bin\smoke-project'
$binaryPath = Join-Path $repoDir 'bin\hx-dist.hl'
if (!(Test-Path -LiteralPath (Join-Path $repoDir 'build.hxml'))) {
    throw 'Run this test from the repository root.'
}
New-Item -ItemType Directory -Force -Path $fixtureDir | Out-Null
Set-Content -LiteralPath (Join-Path $fixtureDir 'Smoke.hx') -Value 'class Smoke { static function main() { trace("smoke"); } }'
Set-Content -LiteralPath (Join-Path $fixtureDir 'js.hxml') -Value @('-cp .', '-main Smoke', '-js app.js')
Set-Content -LiteralPath (Join-Path $fixtureDir 'hl.hxml') -Value @('-cp .', '-main Smoke', '-hl app.hl')
& hl $binaryPath js.hxml $fixtureDir
if ($LASTEXITCODE -ne 0) { throw 'JavaScript packaging failed.' }
& hl $binaryPath -icon (Join-Path $repoDir 'media\hxdist-icon.png') hl.hxml $fixtureDir
if ($LASTEXITCODE -ne 0) { throw 'HashLink icon packaging failed.' }
$archivePath = Join-Path $fixtureDir 'dist\smoke-project_hl_win.zip'
$beforeHash = (Get-FileHash -LiteralPath $archivePath).Hash
& hl $binaryPath -o . hl.hxml $fixtureDir
if ($LASTEXITCODE -ne 1 -or !(Test-Path -LiteralPath (Join-Path $fixtureDir 'Smoke.hx'))) {
    throw 'Unsafe output was not rejected.'
}
& hl $binaryPath missing.hxml $fixtureDir
if ($LASTEXITCODE -ne 1 -or (Get-FileHash -LiteralPath $archivePath).Hash -ne $beforeHash) {
    throw 'Invalid HXML did not preserve the previous package.'
}
$configPath = Join-Path $fixtureDir 'hxdist.json'
Set-Content -LiteralPath $configPath -Value '{"include": "not-an-array"}'
try {
    & hl $binaryPath hl.hxml $fixtureDir
    if ($LASTEXITCODE -ne 1 -or (Get-FileHash -LiteralPath $archivePath).Hash -ne $beforeHash) {
        throw 'Invalid config did not preserve the previous package.'
    }
} finally {
    Remove-Item -LiteralPath $configPath
}
$shellPath = 'C:/Program Files/Git/bin/sh.exe'
if (Test-Path -LiteralPath $shellPath) {
    $previousLibraryPath = $env:LD_LIBRARY_PATH
    try {
        $env:LD_LIBRARY_PATH = 'prior-libs'
        $launcherOutput = & $shellPath 'bin/launcher fixture/run.sh' 'two words' last
        if ($LASTEXITCODE -ne 7 -or $launcherOutput.Count -ne 3 -or !$launcherOutput[0].EndsWith(':prior-libs') -or $launcherOutput[1] -ne 'two words' -or $launcherOutput[2] -ne 'last') {
            throw 'Linux launcher argument, path, or exit-code handling failed.'
        }
    } finally {
        $env:LD_LIBRARY_PATH = $previousLibraryPath
    }
}
Write-Output 'Windows packaging and launcher smoke tests passed.'
