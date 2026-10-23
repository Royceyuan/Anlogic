param([string]$ModelSim='D:/Modelsim/win64/vsim.exe')
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskBuild=Join-Path $taskRoot '_build_main'
New-Item -ItemType Directory -Path $taskBuild -Force | Out-Null
Push-Location (Join-Path $taskRoot 'sim')
try {
    $taskTests=[ordered]@{
        half_stream_physical='viewport_pan_stream'; key1_zoom='viewport_zoom';
        zoom_osd='museum_status_osd'; zoom_osd_physical='zoom_osd_physical'; remote_controls='remote_controls';
        local_controls='local_controls'; application_recovery='application_recovery';
        emergency_recovery='emergency_recovery'; audio_playback_speed='audio_playback_speed';
        subtitle_playback_speed='subtitle_playback_speed'
        wav_address_timing='wav_address_timing'
        overview_black_loading='museum_overview'
        half_memory_bandwidth='half_zoom_memory'
        read_completion='frame_fifo_read_completion'
    }
    foreach($taskName in $taskTests.Keys){
        $taskLog=Join-Path $taskBuild "$taskName.log"
        & $ModelSim -c -do "do run_$($taskTests[$taskName]).do" *> $taskLog
        $taskText=Get-Content -LiteralPath $taskLog -Raw
        if($LASTEXITCODE -ne 0 -or $taskText -notmatch 'PASS' -or
           $taskText -match '#\s+(?:\*\* (?:Fatal|Error)|Errors: [1-9]|FAIL)'){
            throw "Zoom regression failed: $taskLog"
        }
        Write-Output "PASS $taskName"
    }
} finally {Pop-Location}
