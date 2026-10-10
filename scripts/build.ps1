param([string]$TD = 'D:\TD_6.2.1\bin\td_commands_prompt.exe')

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $projectRoot
$buildDir = Join-Path $projectRoot 'build'
$env:SECONDARY_BUILD = $buildDir
$env:SECONDARY_BIT = Join-Path $buildDir 'dual_fpga_museum_terminal_secondary_board.bit'
New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
Write-Host "Building secondary board; reports: $buildDir"
& $TD './scripts/synthesize_and_route.tcl' 2>&1 |
    Out-File -FilePath (Join-Path $buildDir 'console.log') -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw 'Synthesis/P&R failed' }
if (Select-String -LiteralPath (Join-Path $buildDir 'console.log') -Pattern ' ERROR:') {
    throw 'Synthesis/P&R reported an error; bitgen not attempted'
}
& $TD './scripts/generate_bitstream.tcl' 2>&1 |
    Out-File -FilePath (Join-Path $buildDir 'bitgen.log') -Encoding utf8
if ($LASTEXITCODE -ne 0 -or
    (Select-String -LiteralPath (Join-Path $buildDir 'bitgen.log') -Pattern 'REFUSED:') -or
    -not (Select-String -LiteralPath (Join-Path $buildDir 'bitgen.log') -Pattern 'Generate bits file')) {
    throw 'Bit generation failed or timing/dependency gate rejected the build'
}
Get-FileHash -LiteralPath $env:SECONDARY_BIT -Algorithm SHA256
Write-Host 'New build is in build/. The board-passed release bit was not overwritten.'
