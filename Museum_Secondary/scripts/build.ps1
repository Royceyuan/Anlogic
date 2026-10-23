param(
    [ValidateSet('secondary','main')][string]$Target='secondary',
    [string]$TD='D:\TD_6.2.1\bin\td_commands_prompt.exe',
    [string]$Python='D:\Anaconda\python.exe',
    [string]$ModelSim='D:\Modelsim\win64\vsim.exe',
    [switch]$CheckOnly
)
$ErrorActionPreference='Stop'
$taskSecondary=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$taskRoot=if($Target -eq 'main'){Join-Path (Split-Path $taskSecondary -Parent) 'Museum_Main'}else{$taskSecondary}
$taskProject=if($Target -eq 'main'){'museum_main_final.al'}else{'museum_secondary_final.al'}
$taskFolder=if($Target -eq 'main'){'_build_main'}else{'_build_secondary'}
$taskTcl=if($Target -eq 'main'){Join-Path $taskRoot 'scripts/build_project.tcl'}else{Join-Path $PSScriptRoot 'build_project.tcl'}
foreach($taskTool in @($TD,$Python,$ModelSim)){if(-not(Test-Path -LiteralPath $taskTool)){throw "Missing build tool: $taskTool"}}
foreach($taskMatch in [regex]::Matches((Get-Content -LiteralPath (Join-Path $taskRoot $taskProject) -Raw),'<File Path="([^"]+)"')){
    if(-not(Test-Path -LiteralPath (Join-Path $taskRoot $taskMatch.Groups[1].Value))){throw "Missing project dependency: $($taskMatch.Groups[1].Value)"}
}
if(-not(Test-Path -LiteralPath (Join-Path $taskRoot 'seed/formal/build_config.tcl'))){throw 'Missing formal placement seed'}
if($CheckOnly){Write-Output "PASS $taskProject dependencies, tools and formal seed";exit}
$taskBuild=Join-Path $taskRoot $taskFolder
$taskCandidate='release/rebuild_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
$taskPreviousRoute=$env:OFFLINE_AV_ROUTE
$taskPreviousSeed=$env:OFFLINE_AV_SEED
Push-Location -LiteralPath $taskRoot
try {
    & "$PSScriptRoot/capture_offline_build.ps1" -Target $Target
    $env:OFFLINE_AV_ROUTE='1'
    Remove-Item Env:OFFLINE_AV_SEED -ErrorAction SilentlyContinue
    & $TD ($taskTcl.Replace('\','/')) *> "$taskBuild/console.log"
    if($LASTEXITCODE -ne 0){throw 'Synthesis/route process failed'}
    $taskRouteMarker=if($Target -eq 'main'){'MUSEUM_MAIN_ROUTE_FINISHED'}else{'MUSEUM_SECONDARY_ROUTE_FINISHED'}
    if((Get-Content -LiteralPath "$taskBuild/console.log" -Raw) -notmatch $taskRouteMarker){throw 'TD did not complete the route'}
    & "$PSScriptRoot/verify_offline_media.ps1" -Python $Python
    New-Item -ItemType Directory -Path "$taskSecondary/_build_offline_media_tool" -Force | Out-Null
    & $Python "$taskSecondary/tools/OfflineVideo/test_offline_museum_packager.py" *> "$taskSecondary/_build_offline_media_tool/conversion_test.log"
    if($LASTEXITCODE -ne 0){throw 'Media-tool regression failed'}
    Push-Location -LiteralPath "$taskSecondary/sim"
    try {& $ModelSim -c -do 'do run_offline_hdmi_audio.do' *> "$taskSecondary/_build_secondary/hdmi_audio.log"}
    finally {Pop-Location}
    if($LASTEXITCODE -ne 0){throw 'HDMI audio regression failed'}
    if($Target -eq 'main'){
        & 'D:/iverilog/bin/iverilog.exe' -g2012 -DSIM -s tb_mbp1_main_endpoint '-Ptb_mbp1_main_endpoint.ENABLE_CONTROL=1' -o "$taskBuild/main_endpoint_control.vvp" src/ethernet/mbp1_codec.v src/ethernet/mbp1_main_endpoint.v sim/tb_mbp1_main_endpoint.v
        if($LASTEXITCODE -ne 0){throw 'Main endpoint test compile failed'}
        & 'D:/iverilog/bin/vvp.exe' "$taskBuild/main_endpoint_control.vvp" *> "$taskBuild/main_endpoint_control.log"
        if($LASTEXITCODE -ne 0){throw 'Main endpoint regression failed'}
        & (Join-Path $taskRoot 'scripts/verify_zoom.ps1') -ModelSim $ModelSim
    }
    & "$PSScriptRoot/release_offline_av.ps1" -Target $Target -Python $Python -TD $TD -ReleaseDirectory $taskCandidate
    Write-Output "PASS candidate bit in $taskRoot/$taskCandidate; current release was not overwritten"
} finally {
    Pop-Location
    $env:OFFLINE_AV_ROUTE=$taskPreviousRoute
    $env:OFFLINE_AV_SEED=$taskPreviousSeed
}
