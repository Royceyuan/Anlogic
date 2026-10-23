param(
    [ValidateSet('secondary','main')][string]$Target='secondary',
    [string]$Python='D:\Anaconda\python.exe',
    [string]$TD='D:\TD_6.2.1\bin\td_commands_prompt.exe',
    [string]$ReleaseDirectory='release'
)
$ErrorActionPreference='Stop'
$taskSecondary=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$taskRoot=if($Target -eq 'main'){(Resolve-Path -LiteralPath (Join-Path $taskSecondary '..\Museum_Main')).Path}else{$taskSecondary}
$taskFolder=if($Target -eq 'main'){'_build_main'}else{'_build_secondary'}
$taskName=if($Target -eq 'main'){'museum_main_final'}else{'museum_secondary_final'}
$taskBuild=Join-Path $taskRoot $taskFolder
$env:OFFLINE_AV_TARGET=$Target
$env:OFFLINE_AV_PYTHON=$Python
$env:OFFLINE_AV_RELEASE_DIR=$ReleaseDirectory
Push-Location -LiteralPath $taskRoot
try {
    $taskTcl=(Join-Path $PSScriptRoot 'generate_offline_av.tcl').Replace('\','/')
    & $TD $taskTcl *> "$taskBuild\bitgen.log"
    $taskLog=Get-Content -LiteralPath "$taskBuild\bitgen.log" -Raw
    if($LASTEXITCODE -ne 0 -or $taskLog -match ' ERROR:|Traceback|REFUSED' -or $taskLog -notmatch 'PASS OFFLINE_AV_BIT' -or $taskLog -notmatch 'Generate bits file'){throw 'Release refused; inspect bitgen.log'}
    $taskRelease=if([IO.Path]::IsPathRooted($ReleaseDirectory)){$ReleaseDirectory}else{Join-Path $taskRoot $ReleaseDirectory}
    $taskBit=Join-Path $taskRelease "$taskName.bit"
    $taskVerification=Get-Content -LiteralPath "$taskBuild\release_verification.json" -Raw | ConvertFrom-Json
    $taskVerification | Add-Member -NotePropertyName bit -NotePropertyValue "$taskName.bit"
    $taskVerification | Add-Member -NotePropertyName bit_sha256 -NotePropertyValue (Get-FileHash -LiteralPath $taskBit).Hash.ToLower()
    $taskVerification | Add-Member -NotePropertyName generated_at -NotePropertyValue (Get-Date -Format o)
    "$($taskVerification.bit_sha256)  $taskName.bit" | Out-File -LiteralPath "$taskBit.sha256" -Encoding ascii
    $taskSeed=Join-Path (Split-Path $taskRoot -Parent) ("记录文档\构建记录\"+(Split-Path $taskRoot -Leaf)+'\'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
    New-Item -ItemType Directory -Path $taskSeed -Force | Out-Null
    $taskVerification | ConvertTo-Json -Depth 10 | Out-File -LiteralPath "$taskSeed\$taskName.json" -Encoding utf8
    foreach($taskFile in @('final.status','final.ts','final.timing','final.area','build_sources.json','release_verification.json','console.log','bitgen.log')){
        Copy-Item -LiteralPath "$taskBuild\$taskFile" -Destination $taskSeed -Force
    }
    if(Test-Path -LiteralPath "$taskBuild\synthesis.log"){Copy-Item -LiteralPath "$taskBuild\synthesis.log" -Destination $taskSeed -Force}
    Write-Output "PASS $taskBit SHA256=$($taskVerification.bit_sha256); board validation pending"
} finally {
    Pop-Location
    Remove-Item Env:OFFLINE_AV_TARGET,Env:OFFLINE_AV_PYTHON,Env:OFFLINE_AV_RELEASE_DIR -ErrorAction SilentlyContinue
}
