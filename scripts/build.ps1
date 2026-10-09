param(
    [string]$TD = 'D:\TD_6.2.1\bin\td_commands_prompt.exe',
    [ValidateSet('release','shared-clock','relay-diag','handshake-diag')][string]$Variant = 'release'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $projectRoot
$env:SECONDARY_PROJECT = 'hx4s20_secondary_main5e.al'
$env:SECONDARY_TOP = 'top_secondary_main5e'
$env:SECONDARY_SDC = 'constraints/top_secondary_main5e.sdc'
$env:SECONDARY_ADC = 'constraints/top_secondary_main5e.adc'
$buildDir = Join-Path $projectRoot '_build_secondary_help_fixed720_seed6'
$env:SECONDARY_BUILD = $buildDir
$env:SECONDARY_BIT = Join-Path $projectRoot 'release/hx4s20_secondary_help_fixed720.bit'
if ($Variant -eq 'shared-clock') {
    $env:SECONDARY_PROJECT = 'hx4s20_secondary_shared_clock.al'
    $env:SECONDARY_TOP = 'top_secondary_shared_clock'
    $env:SECONDARY_SDC = 'constraints/secondary_shared_clock.sdc'
    $buildDir = Join-Path $projectRoot '_build_secondary_shared_clock'
    $env:SECONDARY_BUILD = $buildDir
    $env:SECONDARY_BIT = Join-Path $projectRoot 'release/hx4s20_secondary_shared_clock.bit'
}
if ($Variant -eq 'relay-diag' -or $Variant -eq 'handshake-diag') {
    $diagName = if ($Variant -eq 'relay-diag') { 'relay' } else { 'handshake' }
    $env:SECONDARY_PROJECT = "hx4s20_secondary_hdmi_${diagName}_diag.al"
    $env:SECONDARY_TOP = "top_secondary_hdmi_${diagName}_diag"
    $env:SECONDARY_SDC = "constraints/secondary_hdmi_${diagName}_diag.sdc"
    $env:SECONDARY_ADC = "constraints/secondary_hdmi_${diagName}_diag.adc"
    $buildDir = Join-Path $projectRoot "_build_secondary_hdmi_${diagName}_diag"
    $env:SECONDARY_BUILD = $buildDir
    $env:SECONDARY_BIT = Join-Path $projectRoot "release/hx4s20_secondary_hdmi_${diagName}_diag.bit"
}
New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
Write-Host "Building secondary board; reports: $buildDir"
& $TD './scripts/build_secondary_main5e_pr.tcl' 2>&1 |
    Out-File -FilePath (Join-Path $buildDir 'console.log') -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw 'P&R failed' }
if (Select-String -LiteralPath (Join-Path $buildDir 'console.log') -Pattern ' ERROR:') {
    throw 'P&R reported an error; no bit generation attempted'
}
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
