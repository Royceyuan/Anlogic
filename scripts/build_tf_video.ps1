param(
    [string]$TD='D:\TD_6.2.1\bin\td_commands_prompt.exe',
    [string]$Iverilog='D:\iverilog\bin\iverilog.exe',
    [string]$Vvp='D:\iverilog\bin\vvp.exe',
    [switch]$TestOnly
)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Push-Location -LiteralPath $taskRoot
try {
    $taskBuild=Join-Path $taskRoot '_build_tf_video'
    New-Item -ItemType Directory -Path $taskBuild -Force | Out-Null
    foreach($taskDelay in @(0,14)) {
        & $Iverilog -g2012 -Wall -s tb_sd_native_read -P "tb_sd_native_read.CARD_DELAY_NS=$taskDelay" -o "$taskBuild\simulation.vvp" src/storage/sd_native_command.v src/storage/sd_native_data_rx.v src/storage/sd_native_read.v sim/tb_sd_native_read.v
        if($LASTEXITCODE -ne 0) {throw 'SD simulation compilation failed'}
        & $Vvp "$taskBuild\simulation.vvp" | Tee-Object -FilePath "$taskBuild\sd_${taskDelay}ns.log"
        if($LASTEXITCODE -ne 0) {throw 'SD simulation failed'}
    }
    foreach($taskModule in @('fat32_mvid_reader','mvid_scale2x','mvid_frame_control')) {
        $taskSource=if($taskModule -eq 'fat32_mvid_reader') {'src/storage'} else {'src/video'}
        & $Iverilog -g2012 -Wall -s "tb_$taskModule" -o "$taskBuild\simulation.vvp" "$taskSource/$taskModule.v" "sim/tb_$taskModule.v"
        if($LASTEXITCODE -ne 0) {throw "Simulation compilation failed: $taskModule"}
        & $Vvp "$taskBuild\simulation.vvp" | Tee-Object -FilePath "$taskBuild\$taskModule.log"
        if($LASTEXITCODE -ne 0) {throw "Simulation failed: $taskModule"}
    }
    & $Iverilog -g2012 -Wall -s tb_fat32_mvid_reader -P 'tb_fat32_mvid_reader.WIDTH=64' -P 'tb_fat32_mvid_reader.SPC=2' -o "$taskBuild\simulation.vvp" src/storage/fat32_mvid_reader.v sim/tb_fat32_mvid_reader.v
    if($LASTEXITCODE -ne 0) {throw 'Multi-block FAT32 simulation compilation failed'}
    & $Vvp "$taskBuild\simulation.vvp" | Tee-Object -FilePath "$taskBuild\fat_multiblock.log"
    if($LASTEXITCODE -ne 0) {throw 'Multi-block FAT32 simulation failed'}
    & $Iverilog -g2012 -Wall -s tb_mvid_scale2x -P 'tb_mvid_scale2x.WIDTH=640' -P 'tb_mvid_scale2x.HEIGHT=360' -o "$taskBuild\simulation.vvp" src/video/mvid_scale2x.v sim/tb_mvid_scale2x.v
    if($LASTEXITCODE -ne 0) {throw '720p scaler simulation compilation failed'}
    & $Vvp "$taskBuild\simulation.vvp" | Tee-Object -FilePath "$taskBuild\scale720.log"
    if($LASTEXITCODE -ne 0) {throw '720p scaler simulation failed'}
    & $Iverilog -g2012 -Wall -s tb_mvid_sdram_turnaround -o "$taskBuild\simulation.vvp" vendor/anlogic_lab6/al_ip/afifo_16_32_256.v vendor/anlogic_lab6/al_ip/afifo_32_16_256.v vendor/anlogic_lab6/frame_fifo_read.v vendor/anlogic_lab6/frame_fifo_write.v vendor/anlogic_lab6/frame_read_write.v sim/tb_mvid_sdram_turnaround.v
    if($LASTEXITCODE -ne 0) {throw 'SDRAM arbitration simulation compilation failed'}
    & $Vvp "$taskBuild\simulation.vvp" | Tee-Object -FilePath "$taskBuild\sdram_turnaround.log"
    if($LASTEXITCODE -ne 0) {throw 'SDRAM arbitration simulation failed'}
    # Some Windows vvp builds return zero even after $fatal; inspect the logs too.
    foreach($taskLog in @('sd_0ns','sd_14ns','fat32_mvid_reader','fat_multiblock','mvid_scale2x','mvid_frame_control','scale720','sdram_turnaround')) {
        $taskResult=Get-Content -LiteralPath "$taskBuild\$taskLog.log" -Raw
        if($taskResult -cnotmatch 'PASS' -or $taskResult -cmatch '(?m)^\s*(FAIL|FATAL|ERROR)\b') {throw "Simulation log rejected: $taskLog"}
    }
    if($TestOnly) {return}
    [xml]$taskProject=Get-Content -LiteralPath 'secondary_tf_video.al' -Raw
    $taskPaths=@($taskProject.SelectNodes('//Source_Files//File') | ForEach-Object {$_.Path})
    $taskPaths+=@('secondary_tf_video.al','scripts/build_tf_video.ps1','scripts/build_tf_video.tcl','scripts/generate_tf_video.tcl','vendor/anlogic_lab6/sdram/enc_file/global_def.v','sim/tb_mvid_sdram_turnaround.v')
    $taskHashes=@{}
    foreach($taskPath in $taskPaths) {$taskHashes[$taskPath]=(Get-FileHash -LiteralPath $taskPath).Hash}
    $taskHashes | ConvertTo-Json | Out-File -LiteralPath "$taskBuild\source_hashes.json" -Encoding utf8
    & $TD './scripts/build_tf_video.tcl' *> "$taskBuild\console.log"
    if($LASTEXITCODE -ne 0) {throw 'Offline video synthesis/route failed'}
    foreach($taskPath in $taskPaths) {
        if((Get-FileHash -LiteralPath $taskPath).Hash -ne $taskHashes[$taskPath]) {throw "Source changed during build: $taskPath"}
    }
    & $TD './scripts/generate_tf_video.tcl' *> "$taskBuild\bitgen.log"
    if($LASTEXITCODE -ne 0 -or -not (Select-String -LiteralPath "$taskBuild\bitgen.log" -Pattern 'Generate bits file')) {throw 'Offline video bit generation refused or failed'}
    Get-FileHash -LiteralPath "$taskBuild\secondary_tf_video.bit"
} finally {Pop-Location}
