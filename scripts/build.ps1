param([string]$TD = 'D:\TD_6.2.1\bin\td_commands_prompt.exe')

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $projectRoot
$buildDir = Join-Path $projectRoot '_build_secondary_help_20261002'
$env:SECONDARY_BUILD = $buildDir
$env:SECONDARY_BIT = Join-Path $projectRoot 'release/hx4s20_secondary_help.bit'
New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
Write-Host "Building secondary board; reports: $buildDir"
& $TD './scripts/build_secondary_main5e_pr.tcl' 2>&1 |
    Out-File -FilePath (Join-Path $buildDir 'console.log') -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw 'P&R failed' }
& $TD './scripts/build_secondary_main5e_bitgen.tcl' 2>&1 |
    Out-File -FilePath (Join-Path $buildDir 'bitgen.log') -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw 'Bit generation failed' }
if (Select-String -LiteralPath (Join-Path $buildDir 'bitgen.log') -Pattern 'REFUSED:') {
    throw 'Bit generation gate rejected the build; inspect reports'
}
if (-not (Select-String -LiteralPath (Join-Path $buildDir 'bitgen.log') -Pattern 'Generate bits file')) {
    throw 'Bit generation did not confirm an output; inspect bitgen.log'
}
Get-FileHash -LiteralPath $env:SECONDARY_BIT -Algorithm SHA256
