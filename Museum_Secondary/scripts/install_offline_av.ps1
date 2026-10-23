param([Parameter(Mandatory=$true)][string]$Manifest,[switch]$GuideOnly,[switch]$ArtifactsOnly,[ValidateSet(0,1,2,3,4)][int]$ArtifactIndex)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$taskExpected='\\?\Volume{cfc56033-a85b-11f1-a1f0-c0353219a8b6}\'
function Assert-Card {
    $taskVolume=Get-Volume -DriveLetter E
    if($taskVolume.UniqueId -ne $taskExpected -or $taskVolume.FileSystem -ne 'FAT32'){throw 'Not the confirmed secondary FAT32 TF card'}
}
$taskManifestPath=(Resolve-Path -LiteralPath $Manifest).Path
$taskSet=Get-Content -LiteralPath $taskManifestPath -Raw | ConvertFrom-Json
$taskSingle=$PSBoundParameters.ContainsKey('ArtifactIndex')
if(($GuideOnly -and $ArtifactsOnly) -or ($taskSingle -and ($GuideOnly -or $ArtifactsOnly))){throw 'Choose only one partial update mode'}
$taskNames=@(if($taskSingle){"ART$ArtifactIndex.BIN"}elseif($GuideOnly){'GUIDE.BIN','SUB5.BIN'}elseif($ArtifactsOnly){'ART0.BIN','ART1.BIN','ART2.BIN','ART3.BIN','ART4.BIN'}else{'ART0.BIN','ART1.BIN','ART2.BIN','ART3.BIN','ART4.BIN','GUIDE.BIN','EVAC.BIN','SUB0.BIN','SUB1.BIN','SUB2.BIN','SUB3.BIN','SUB4.BIN','SUB5.BIN'})
if($taskSet.format -ne 'museum offline AV install set' -or $taskSet.files.Count -ne $taskNames.Count){throw 'Unexpected media set size or format'}
foreach($taskName in $taskNames){if(@($taskSet.files | Where-Object {$_.file -ceq $taskName}).Count -ne 1){throw 'Missing or duplicate target name'}}
foreach($taskRow in $taskSet.files){
    if((Get-FileHash -LiteralPath $taskRow.path -Algorithm SHA256).Hash -ne $taskRow.sha256){throw "Local hash mismatch: $($taskRow.file)"}
}
Assert-Card
$taskBackup=Join-Path (Split-Path $taskRoot -Parent) ('TF卡备份\副板音视频_OSD更新前_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $taskBackup | Out-Null
$taskRecords=@()
foreach($taskRow in $taskSet.files){
    Assert-Card
    $taskTarget=Join-Path 'E:\' $taskRow.file
    $taskOldHash=if(Test-Path -LiteralPath $taskTarget){(Get-FileHash -LiteralPath $taskTarget).Hash}else{$null}
    if($taskOldHash -eq $taskRow.sha256){
        $taskRecords+=@{file=$taskRow.file;sha256=$taskRow.sha256;action='unchanged-readback-verified'};continue
    }
    if(Test-Path -LiteralPath $taskTarget){
        $taskSaved=Join-Path $taskBackup $taskRow.file
        Copy-Item -LiteralPath $taskTarget -Destination $taskSaved
        if((Get-FileHash -LiteralPath $taskSaved).Hash -ne $taskOldHash){throw 'Backup hash mismatch'}
    }
    if((Get-Volume -DriveLetter E).SizeRemaining -lt $taskRow.file_bytes+1048576){throw 'Insufficient TF free space for staged replacement'}
    $taskStaged=Join-Path 'E:\' ($taskRow.file+'.NEW')
    if(Test-Path -LiteralPath $taskStaged){throw "Unreviewed partial file exists: $taskStaged"}
    Copy-Item -LiteralPath $taskRow.path -Destination $taskStaged
    if((Get-FileHash -LiteralPath $taskStaged).Hash -ne $taskRow.sha256){throw 'Staged TF readback mismatch'}
    Assert-Card
    Move-Item -LiteralPath $taskStaged -Destination $taskTarget -Force
    if((Get-FileHash -LiteralPath $taskTarget).Hash -ne $taskRow.sha256){throw 'Published TF readback mismatch'}
    $taskRecords+=@{file=$taskRow.file;sha256=$taskRow.sha256;action='backed-up-and-updated'}
    Write-Output "PASS backed up, replaced and readback-verified: $($taskRow.file)"
}
$taskResult=@{volume_id=$taskExpected;backup=$taskBackup;manifest=$taskManifestPath;files=$taskRecords;readback_verified=$true;board_verified=$false}
$taskResult | ConvertTo-Json -Depth 7 | Out-File -LiteralPath (Join-Path $taskBackup 'installation.json') -Encoding utf8
$taskRecord=Join-Path (Split-Path $taskRoot -Parent) '记录文档\副板写卡记录'
New-Item -ItemType Directory -Path $taskRecord -Force | Out-Null
$taskResult | ConvertTo-Json -Depth 7 | Out-File -LiteralPath (Join-Path $taskRecord ((Get-Date -Format 'yyyyMMdd_HHmmss')+'_offline_av_installation.json')) -Encoding utf8
Write-Output 'PASS media/subtitle TF readback; installer finished. Use Windows safe eject before removal.'
