param(
    [string]$ExampleRoot = 'D:\VSCode\CodeFiles\Git_TD\HX4S20_Contest_202606\2_Example\HDMI环出实验\eg4s324_hdmi_loop',
    [string]$TD = 'D:\TD_6.2.1\bin\td_commands_prompt.exe'
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$factoryRoot = (Resolve-Path -LiteralPath $ExampleRoot).Path
$buildRoot = Join-Path $repoRoot '_build_secondary_official_hdmi_loop'
$stageRoot = Join-Path $buildRoot 'source'
New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
# Mechanical, immutable snapshot of the supplied official source/IP assets.
$assets = Get-ChildItem -LiteralPath $factoryRoot -Recurse -File | Where-Object {
    $_.Extension -in @('.v','.vhd','.vx','.ipc','.mif','.adc','.sdc') -and
    $_.FullName -notmatch '[\\/]work[\\/]|_Runs[\\/]|[\\/]chip_debugger[\\/]'
}
foreach ($asset in $assets) {
    $target = Join-Path $stageRoot $asset.FullName.Substring($factoryRoot.Length).TrimStart('\','/')
    New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $asset.FullName -Destination $target -Force
}
$utf8 = [Text.UTF8Encoding]::new($false)
$project = Get-Content -LiteralPath (Join-Path $factoryRoot 'hdmi_loop/hdmi_loop.al') -Raw
$project = [regex]::Replace($project,'(<Project[^>]* Path=")[^"]*','$1.')
$project = $project.Replace('<Name>hdmi_loop</Name>','<Name>hx4s20_secondary_official_hdmi_loop</Name>').Replace('UsedInP&R','UsedInP&amp;R')
$project = [regex]::Replace($project,'<File Path="([^"]+)"', {
    param($match)
    $full = [IO.Path]::GetFullPath((Join-Path (Join-Path $stageRoot 'hdmi_loop') $match.Groups[1].Value))
    '<File Path="' + [IO.Path]::GetRelativePath($buildRoot,$full).Replace('\','/') + '"'
})
[IO.File]::WriteAllText((Join-Path $buildRoot 'hx4s20_secondary_official_hdmi_loop.al'),$project,$utf8)
$ramPath = Join-Path $stageRoot 'hdmi_loop/al_ip/myedid_new.v'
$mifPath = (Join-Path $stageRoot 'hdmi_loop/al_ip/edid_mif/edid_1280720_with_audio.mif').Replace('\','/')
$ramSource = (Get-Content -LiteralPath $ramPath -Raw).Replace('edid_mif/edid_1280720_with_audio.mif',$mifPath)
[IO.File]::WriteAllText($ramPath,$ramSource,$utf8)
$buildPath = $buildRoot.Replace('\','/')
$repoPath = $repoRoot.Replace('\','/')
$tcl = @"
import_device eagle_s20.db -package EG4S20BG256
cd $buildPath
open_project $buildPath/hx4s20_secondary_official_hdmi_loop.al -single_run
load_run_param -run syn_1
elaborate -top hdmi_loop
read_adc $buildPath/source/hdmi_loop/hdmi_mipi_demo.adc
clear_sdc -user
read_sdc $repoPath/scripts/official_hdmi_loop_baseline.sdc
optimize_rtl
optimize_gate -packarea $buildPath/official_gate.area
legalize_phy_inst
update_timing
export_db $buildPath/official_gate.db
set_param place opt_timing high
set_param place seed 1
place
set_param route fix_hold off
route
fix_hold
set_param route fix_hold on
update_timing -mode final
report_area -io_info -file $buildPath/official_final.area
report_qor -step route -file $buildPath/official_final.qor
report_timing_status -file $buildPath/official_final.ts
report_timing_summary -file $buildPath/official_final.timing
flow_status -file $buildPath/official_final.status
export_db $buildPath/official_pr.db
exit
"@
[IO.File]::WriteAllText((Join-Path $buildRoot 'rebuild_official.tcl'),$tcl,$utf8)
Set-Location -LiteralPath $repoRoot
& $TD './_build_secondary_official_hdmi_loop/rebuild_official.tcl' 2>&1 |
    Out-File (Join-Path $buildRoot 'rebuild_console.log') -Encoding utf8
$log = Get-Content -LiteralPath (Join-Path $buildRoot 'rebuild_console.log') -Raw
if ($LASTEXITCODE -ne 0 -or $log -match ' ERROR:|coredump|No clock match|Clock group is empty|black box' -or
    $log -notmatch 'No multi-drive\.' -or $log -notmatch 'No abnormal timing path\.') {
    throw 'Official baseline failed compile/DRC; bitgen skipped'
}
# User requested the original official baseline, not a production release.
# Do not mislabel negative setup as timing-closed or hide it with exceptions.
Get-Content -LiteralPath (Join-Path $buildRoot 'official_final.ts')
Write-Warning 'BOARD-TEST BASELINE ONLY: inspect setup/hold; this script does not certify production timing closure.'
$bitPath = (Join-Path $repoRoot 'release/hx4s20_secondary_official_hdmi_loop_baseline.bit').Replace('\','/')
$bitTcl = "import_device eagle_s20.db -package EG4S20BG256`nimport_db $buildPath/official_pr.db`nbitgen -bit $bitPath`nexit`n"
[IO.File]::WriteAllText((Join-Path $buildRoot 'rebuild_bitgen.tcl'),$bitTcl,$utf8)
& $TD './_build_secondary_official_hdmi_loop/rebuild_bitgen.tcl' 2>&1 |
    Out-File (Join-Path $buildRoot 'rebuild_bitgen.log') -Encoding utf8
if ($LASTEXITCODE -ne 0 -or -not (Select-String -LiteralPath (Join-Path $buildRoot 'rebuild_bitgen.log') -Pattern 'Generate bits file')) {
    throw 'Official bit generation did not confirm an output'
}
Get-FileHash -LiteralPath $bitPath -Algorithm SHA256
