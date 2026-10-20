param([string]$Destination=(Join-Path $PSScriptRoot '..\..\_media_tf_demo'))
$ErrorActionPreference='Stop'
$taskRepo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$taskBundle=Join-Path $taskRepo 'assets\tf_video_640x480_30fps'
$taskManifest=Get-Content -LiteralPath (Join-Path $taskBundle 'delivery_manifest.json') -Raw | ConvertFrom-Json
$taskZip=Join-Path $taskBundle 'VIDEO0.BIN.zip'
if((Get-FileHash -LiteralPath $taskZip -Algorithm SHA256).Hash -ne $taskManifest.archive_sha256){
    throw 'Archive hash mismatch or Git LFS pointer. Run git lfs pull before preparing the demo.'
}
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$taskDestination=(Resolve-Path -LiteralPath $Destination).Path
$taskFinal=Join-Path $taskDestination 'VIDEO0.BIN'
if(Test-Path -LiteralPath $taskFinal){
    if((Get-FileHash -LiteralPath $taskFinal -Algorithm SHA256).Hash -ne $taskManifest.video_sha256){
        throw 'Destination contains a different VIDEO0.BIN. Back it up first; nothing was overwritten.'
    }
}else{
    $taskTemp=Join-Path $taskDestination ('.prepare_480p_'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $taskTemp | Out-Null
    Expand-Archive -LiteralPath $taskZip -DestinationPath $taskTemp
    $taskExtracted=Join-Path $taskTemp 'VIDEO0.BIN'
    if((Get-Item -LiteralPath $taskExtracted).Length -ne $taskManifest.video_bytes -or
       (Get-FileHash -LiteralPath $taskExtracted -Algorithm SHA256).Hash -ne $taskManifest.video_sha256){
        throw "Extracted demo mismatch. Evidence retained in $taskTemp"
    }
    Move-Item -LiteralPath $taskExtracted -Destination $taskFinal
    Remove-Item -LiteralPath $taskTemp
}
Write-Output "PASS 640x480 30fps demo: $taskFinal"
Write-Output 'Use experiments/tf_video/secondary_tf_video_640x480_30fps_guard8.bit; display connects to HDMIB.'
Write-Output 'After JTAG loading, reinsert the TF card and press KEY1. KEY2 pauses/resumes. This independent baseline is silent.'
