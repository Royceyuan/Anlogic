param(
    [string]$Python='D:\Anaconda\python.exe',
    [string]$Iverilog='D:\iverilog\bin\iverilog.exe',
    [string]$Vvp='D:\iverilog\bin\vvp.exe'
)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$taskBuild=Join-Path $taskRoot '_build_offline_integration'
New-Item -ItemType Directory -Path $taskBuild -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $taskRoot '_build_secondary') -Force | Out-Null
$taskPreviousUTF8=$env:PYTHONUTF8
$env:PYTHONUTF8='1'
Push-Location -LiteralPath $taskRoot
try {
    & $Python tools/OfflineVideo/build_subtitle_tracks.py
    if($LASTEXITCODE -ne 0){throw 'Local subtitle resource generation failed'}
    & $Python tools/OfflineVideo/test_mvid2.py | Tee-Object -FilePath "$taskBuild\media_format.log"
    if($LASTEXITCODE -ne 0){throw 'Media-format self-test failed'}
    $taskCases=[ordered]@{
        fat32_mvid_reader=@('src/storage/fat32_mvid_reader.v')
        mvid2_reader=@('src/storage/fat32_mvid_reader.v')
        mvid_seek_cache=@('src/storage/fat32_mvid_reader.v')
        mvid_geometry=@('src/storage/fat32_mvid_reader.v')
        mvid_pcm_commit=@('src/audio/mvid_pcm_commit.v')
        secondary_offline_scene_control=@('src/secondary/secondary_offline_scene_control.v')
        mvid_frame_control=@('src/video/mvid_frame_control.v')
        offline_file_switch=@('src/video/mvid_frame_control.v','src/secondary/secondary_offline_file_control.v')
        secondary_offline_request_cdc=@('src/secondary/secondary_offline_request_cdc.v')
        mbp1_secondary_endpoint=@('src/ethernet/mbp1_codec.v','src/ethernet/mbp1_secondary_endpoint.v')
        offline_sd_arbiter=@('src/storage/offline_sd_arbiter.v')
        offline_audio_output=@('src/secondary/secondary_offline_request_cdc.v','src/audio/offline_audio_output.v')
        offline_audio_fade=@('src/secondary/secondary_offline_request_cdc.v','src/audio/offline_audio_output.v')
        offline_audio_continuity=@('src/secondary/secondary_offline_request_cdc.v','src/audio/offline_audio_output.v','src/audio/mvid_pcm_commit.v')
        secondary_offline_main_timeline=@('src/secondary/secondary_offline_main_timeline.v')
        museum_voice_handoff=@('sim/reference_main/museum_voice_handoff.v')
        offline_voice_protocol=@('src/ethernet/mbp1_codec.v','src/ethernet/mbp1_secondary_endpoint.v','sim/reference_main/mbp1_main_endpoint.v')
        offline_osd_switch=@('src/secondary/secondary_offline_scene_control.v')
        offline_av_pipeline=@('src/video/mvid_frame_control.v','src/audio/mvid_pcm_commit.v','src/audio/offline_audio_output.v','src/secondary/secondary_offline_file_control.v','src/secondary/secondary_offline_request_cdc.v')
        offline_subtitle_files=@('src/video/museum_subtitle_overlay.v','src/video/subtitle_bitmap_ram.v')
        secondary_offline_overlay=@('src/secondary/secondary_offline_overlay.v','src/secondary/secondary_offline_font.v','src/video/audio_visualizer_overlay.v')
        secondary_compact_waveform=@('src/video/audio_visualizer_overlay.v')
    }
    & $Iverilog -g2012 -DSIM '-Ptb_museum_subtitle_overlay.CORE_HALF=5' '-Ptb_museum_subtitle_overlay.PIPE_RAM_OUTPUT=1' '-Ptb_museum_subtitle_overlay.SPEED_TEST=1' '-Ptb_museum_subtitle_overlay.VISIBILITY_TEST=1' -s tb_museum_subtitle_overlay -o "$taskBuild\subtitle_reuse.vvp" src/video/subtitle_bitmap_ram.v src/video/museum_subtitle_overlay.v sim/tb_museum_subtitle_overlay.v
    if($LASTEXITCODE -ne 0){throw 'Subtitle reuse compile failed'}
    & $Vvp "$taskBuild\subtitle_reuse.vvp" | Tee-Object -FilePath "$taskBuild\subtitle_reuse.log"
    if($LASTEXITCODE -ne 0 -or (Get-Content "$taskBuild\subtitle_reuse.log" -Raw) -cnotmatch 'PASS'){throw 'Subtitle reuse simulation failed'}
    foreach($taskTrack in @(1,5)){
        & $Iverilog -g2012 -DSIM '-Ptb_museum_subtitle_overlay.CORE_HALF=5' '-Ptb_museum_subtitle_overlay.PIPE_RAM_OUTPUT=1' '-Ptb_museum_subtitle_overlay.SPEED_TEST=1' '-Ptb_museum_subtitle_overlay.VISIBILITY_TEST=1' '-Ptb_museum_subtitle_overlay.SCROLL_TEST=1' "-Ptb_museum_subtitle_overlay.TRACK=$taskTrack" -s tb_museum_subtitle_overlay -o "$taskBuild\subtitle_slide_$taskTrack.vvp" src/video/subtitle_bitmap_ram.v src/video/museum_subtitle_overlay.v sim/tb_museum_subtitle_overlay.v
        if($LASTEXITCODE -ne 0){throw 'Subtitle slide compile failed'}
        & $Vvp "$taskBuild\subtitle_slide_$taskTrack.vvp" | Tee-Object -FilePath "$taskBuild\subtitle_slide_$taskTrack.log"
        if($LASTEXITCODE -ne 0 -or (Get-Content "$taskBuild\subtitle_slide_$taskTrack.log" -Raw) -cnotmatch 'PASS'){throw 'Subtitle slide failed'}
    }
    foreach($taskName in $taskCases.Keys) {
        $taskSources=$taskCases[$taskName]
        & $Iverilog -g2012 -DSIM -Wall -s "tb_$taskName" -o "$taskBuild\$taskName.vvp" @taskSources "sim/tb_$taskName.v"
        if($LASTEXITCODE -ne 0){throw "Compile failed: $taskName"}
        & $Vvp "$taskBuild\$taskName.vvp" | Tee-Object -FilePath "$taskBuild\$taskName.log"
        $taskText=Get-Content -LiteralPath "$taskBuild\$taskName.log" -Raw
        if($LASTEXITCODE -ne 0 -or $taskText -cnotmatch 'PASS' -or $taskText -cmatch '(?m)^\s*(FAIL|FATAL|ERROR)\b') {
            throw "Simulation failed: $taskName"
        }
    }
    & $Python scripts/test_offline_main_state.py
    if($LASTEXITCODE -ne 0){throw 'Actual OSD state decoder failed'}
    & $Iverilog -g2012 -DSIM -s tb_audio_visualizer_overlay -o "$taskBuild\main_visualizer_reuse.vvp" src/video/audio_visualizer_overlay.v sim/reference_main/tb_audio_visualizer_overlay.v
    if($LASTEXITCODE -ne 0){throw 'Main visualizer reuse compile failed'}
    & $Vvp "$taskBuild\main_visualizer_reuse.vvp" | Tee-Object -FilePath "$taskBuild\main_visualizer_reuse.log"
    if($LASTEXITCODE -ne 0 -or (Get-Content "$taskBuild\main_visualizer_reuse.log" -Raw) -cnotmatch 'PASS'){throw 'Main visualizer reuse failed'}
    $taskFiles=@('src/secondary/top_secondary_tf_video.v','src/secondary/top_secondary_offline_av.v',
        'src/secondary/top_secondary_main5e_netdiag.v','museum_secondary_final.al',
        'constraints/secondary_offline_av.adc','constraints/secondary_offline_av.sdc',
        'tools/OfflineVideo/mvid2.py','tools/OfflineVideo/test_mvid2.py',
        'scripts/test_offline_main_state.py','sim/reference_main/tb_audio_visualizer_overlay.v',
        'sim/tb_museum_subtitle_overlay.v','scripts/verify_offline_media.ps1')
    foreach($taskName in $taskCases.Keys){$taskFiles+=@($taskCases[$taskName]);$taskFiles+="sim/tb_$taskName.v"}
    $taskFiles=@($taskFiles | Select-Object -Unique)
    $taskHashes=@{}
    foreach($taskFile in $taskFiles){$taskHashes[$taskFile]=(Get-FileHash -LiteralPath $taskFile -Algorithm SHA256).Hash}
    $taskHashes | ConvertTo-Json | Out-File -LiteralPath "$taskBuild\source_sha256.json" -Encoding utf8
    Write-Output 'PASS offline media interfaces; this does not assert full FPGA integration or board validation'
} finally {
    $env:PYTHONUTF8=$taskPreviousUTF8
    Pop-Location
}
