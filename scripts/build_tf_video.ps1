param(
    [string]$TD='D:\TD_6.2.1\bin\td_commands_prompt.exe',
    [string]$Iverilog='D:\iverilog\bin\iverilog.exe',
    [string]$Vvp='D:\iverilog\bin\vvp.exe',
    [ValidateSet(30)][int]$FPS=30,
    [ValidateSet(360,480)][int]$Height=360,
    [switch]$TestOnly
)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$taskPreviousFPS=$env:TF_VIDEO_FPS
$taskPreviousHeight=$env:TF_VIDEO_HEIGHT
$env:TF_VIDEO_FPS="$FPS"
$env:TF_VIDEO_HEIGHT="$Height"
Push-Location -LiteralPath $taskRoot
try {
    $taskFolder=if($Height -eq 360){'_build_tf_video'}else{'_build_tf_video_480p'}
    $taskBuild=Join-Path $taskRoot $taskFolder
    New-Item -ItemType Directory -Path $taskBuild -Force | Out-Null
    foreach($taskDelay in @(0,14)) {
        & $Iverilog -g2012 -Wall -s tb_sd_native_read -P "tb_sd_native_read.CARD_DELAY_NS=$taskDelay" -o "$taskBuild\simulation.vvp" src/storage/sd_native_command.v src/storage/sd_native_data_rx.v src/storage/sd_native_read.v sim/tb_sd_native_read.v
        if($LASTEXITCODE -ne 0) {throw 'SD simulation compilation failed'}
        & $Vvp "$taskBuild\simulation.vvp" | Tee-Object -FilePath "$taskBuild\sd_${taskDelay}ns.log"
        if($LASTEXITCODE -ne 0) {throw 'SD simulation failed'}
    }
    foreach($taskModule in @('fat32_mvid_reader','mvid_scale2x','mvid_frame_control')) {
        $taskSource=if($taskModule -eq 'fat32_mvid_reader') {'src/storage'} else {'src/video'}
        $taskRateParams=if($taskModule -eq 'mvid_scale2x'){@()}else{@('-P',"tb_$taskModule.FPS=$FPS")}
        if($taskModule -eq 'mvid_frame_control') {$taskRateParams+=@('-P',"tb_mvid_frame_control.SLOTS=$(if($Height -eq 480){3}else{2})")}
        & $Iverilog -g2012 -Wall -s "tb_$taskModule" @taskRateParams -o "$taskBuild\simulation.vvp" "$taskSource/$taskModule.v" "sim/tb_$taskModule.v"
        if($LASTEXITCODE -ne 0) {throw "Simulation compilation failed: $taskModule"}
        & $Vvp "$taskBuild\simulation.vvp" | Tee-Object -FilePath "$taskBuild\$taskModule.log"
        if($LASTEXITCODE -ne 0) {throw "Simulation failed: $taskModule"}
    }
    & $Iverilog -g2012 -Wall -s tb_fat32_mvid_reader -P "tb_fat32_mvid_reader.FPS=$FPS" -P 'tb_fat32_mvid_reader.WIDTH=64' -P 'tb_fat32_mvid_reader.SPC=2' -o "$taskBuild\simulation.vvp" src/storage/fat32_mvid_reader.v sim/tb_fat32_mvid_reader.v
    if($LASTEXITCODE -ne 0) {throw 'Multi-block FAT32 simulation compilation failed'}
    & $Vvp "$taskBuild\simulation.vvp" | Tee-Object -FilePath "$taskBuild\fat_multiblock.log"
    if($LASTEXITCODE -ne 0) {throw 'Multi-block FAT32 simulation failed'}
    & $Iverilog -g2012 -Wall -s tb_mvid_scale2x -P 'tb_mvid_scale2x.WIDTH=640' -P "tb_mvid_scale2x.HEIGHT=$Height" -o "$taskBuild\simulation.vvp" src/video/mvid_scale2x.v sim/tb_mvid_scale2x.v
    if($LASTEXITCODE -ne 0) {throw '720p scaler simulation compilation failed'}
    & $Vvp "$taskBuild\simulation.vvp" | Tee-Object -FilePath "$taskBuild\scale720.log"
    if($LASTEXITCODE -ne 0) {throw '720p scaler simulation failed'}
    & $Iverilog -g2012 -Wall -s tb_mvid_sdram_turnaround -o "$taskBuild\simulation.vvp" vendor/anlogic_lab6/al_ip/afifo_16_32_256.v vendor/anlogic_lab6/al_ip/afifo_32_16_256.v vendor/anlogic_lab6/frame_fifo_read.v vendor/anlogic_lab6/frame_fifo_write.v vendor/anlogic_lab6/frame_read_write.v sim/tb_mvid_sdram_turnaround.v
    if($LASTEXITCODE -ne 0) {throw 'SDRAM arbitration simulation compilation failed'}
    & $Vvp "$taskBuild\simulation.vvp" | Tee-Object -FilePath "$taskBuild\sdram_turnaround.log"
    if($LASTEXITCODE -ne 0) {throw 'SDRAM arbitration simulation failed'}
    if($Height -eq 480) {
            & $Iverilog -g2012 -Wall -s tb_mvid_geometry -o "$taskBuild\simulation.vvp" src/storage/fat32_mvid_reader.v sim/tb_mvid_geometry.v
            if($LASTEXITCODE -ne 0) {throw '480p filesystem geometry compilation failed'}
            & $Vvp "$taskBuild\simulation.vvp" | Tee-Object -FilePath "$taskBuild\geometry480.log"
            & $Iverilog -g2012 -Wall -s tb_mvid_scan_concurrent -o "$taskBuild\simulation.vvp" vendor/anlogic_lab6/al_ip/afifo_16_32_256.v vendor/anlogic_lab6/al_ip/afifo_32_16_256.v vendor/anlogic_lab6/frame_fifo_read.v vendor/anlogic_lab6/frame_fifo_write.v vendor/anlogic_lab6/frame_read_write.v src/video/mvid_scale2x.v sim/tb_mvid_scan_concurrent.v
            if($LASTEXITCODE -ne 0) {throw '480p concurrent scan compilation failed'}
            & $Vvp "$taskBuild\simulation.vvp" | Tee-Object -FilePath "$taskBuild\scan_concurrent.log"
            foreach($taskLog in @('geometry480','scan_concurrent')) {
                $taskResult=Get-Content -LiteralPath "$taskBuild\$taskLog.log" -Raw
                if($taskResult -cnotmatch 'PASS' -or $taskResult -cmatch '(?m)^\s*(FAIL|FATAL|ERROR)\b') {throw "480p simulation failed: $taskLog"}
            }
            & $Iverilog -g2012 -Wall -s tb_mvid_frame_control -P 'tb_mvid_frame_control.FPS=30' -P 'tb_mvid_frame_control.SLOTS=3' -P 'tb_mvid_frame_control.PERFORMANCE=1' -P 'tb_mvid_frame_control.EXTRA_GAP=2' -o "$taskBuild\simulation.vvp" src/video/mvid_frame_control.v sim/tb_mvid_frame_control.v
            if($LASTEXITCODE -ne 0) {throw 'Buffer cadence simulation compilation failed'}
            & $Vvp "$taskBuild\simulation.vvp" | Tee-Object -FilePath "$taskBuild\cadence_3slot.log"
            $taskCadence=Get-Content -LiteralPath "$taskBuild\cadence_3slot.log" -Raw
            if($LASTEXITCODE -ne 0 -or $taskCadence -cnotmatch 'PASS' -or $taskCadence -cmatch '(?m)^\s*(FAIL|FATAL|ERROR)\b') {throw 'Buffer cadence simulation failed'}
    }
    # Some Windows vvp builds return zero even after $fatal; inspect the logs too.
    foreach($taskLog in @('sd_0ns','sd_14ns','fat32_mvid_reader','fat_multiblock','mvid_scale2x','mvid_frame_control','scale720','sdram_turnaround')) {
        $taskResult=Get-Content -LiteralPath "$taskBuild\$taskLog.log" -Raw
        if($taskResult -cnotmatch 'PASS' -or $taskResult -cmatch '(?m)^\s*(FAIL|FATAL|ERROR)\b') {throw "Simulation log rejected: $taskLog"}
    }
    if($TestOnly) {return}
    $taskProjectFile=if($Height -eq 360){'secondary_tf_video.al'}else{'secondary_tf_video_480p.al'}
    [xml]$taskProject=Get-Content -LiteralPath $taskProjectFile -Raw
    $taskPaths=@($taskProject.SelectNodes('//Source_Files//File') | ForEach-Object {$_.Path})
    $taskPaths+=@($taskProjectFile,'scripts/build_tf_video.ps1','scripts/build_tf_video.tcl','scripts/generate_tf_video.tcl','vendor/anlogic_lab6/sdram/enc_file/global_def.v','sim/tb_mvid_sdram_turnaround.v','sim/tb_sd_native_read.v')
    $taskPaths+=@(Get-ChildItem -LiteralPath sim -Filter 'tb_*mvid*.v' | ForEach-Object {'sim/'+$_.Name})
    $taskHashes=@{}
    foreach($taskPath in $taskPaths) {$taskHashes[$taskPath]=(Get-FileHash -LiteralPath $taskPath).Hash}
    $taskHashes | ConvertTo-Json | Out-File -LiteralPath "$taskBuild\source_hashes.json" -Encoding utf8
    @{fps=$FPS;height=$Height;define="TF_VIDEO_HEIGHT=$Height";project=$taskProjectFile} | ConvertTo-Json | Out-File -LiteralPath "$taskBuild\build_config.json" -Encoding utf8
    & $TD './scripts/build_tf_video.tcl' *> "$taskBuild\console.log"
    if($LASTEXITCODE -ne 0) {throw 'Offline video synthesis/route failed'}
    foreach($taskPath in $taskPaths) {
        if((Get-FileHash -LiteralPath $taskPath).Hash -ne $taskHashes[$taskPath]) {throw "Source changed during build: $taskPath"}
    }
    & $TD './scripts/generate_tf_video.tcl' *> "$taskBuild\bitgen.log"
    if($LASTEXITCODE -ne 0 -or -not (Select-String -LiteralPath "$taskBuild\bitgen.log" -Pattern 'Generate bits file')) {throw 'Offline video bit generation refused or failed'}
    Get-FileHash -LiteralPath "$taskBuild\secondary_tf_video.bit"
} finally {$env:TF_VIDEO_FPS=$taskPreviousFPS;$env:TF_VIDEO_HEIGHT=$taskPreviousHeight;Pop-Location}
