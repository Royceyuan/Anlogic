param([ValidateSet('secondary','main')][string]$Target='secondary')
$ErrorActionPreference='Stop'
$taskSecondary=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$taskRoot=if($Target -eq 'main'){(Resolve-Path -LiteralPath (Join-Path $taskSecondary '..\Museum_Main')).Path}else{$taskSecondary}
$taskProject=if($Target -eq 'main'){'museum_main_final.al'}else{'museum_secondary_final.al'}
$taskBuild=if($Target -eq 'main'){'_build_main'}else{'_build_secondary'}
New-Item -ItemType Directory -Path (Join-Path $taskRoot $taskBuild) -Force | Out-Null
$taskProjectText=Get-Content -LiteralPath (Join-Path $taskRoot $taskProject) -Raw
# TD accepts legacy project attributes containing a literal '&'; its project
# format is not necessarily XML-parser-clean. Read only exact File Path fields.
$taskSources=@($taskProject,'seed/formal/build_config.tcl')+@([regex]::Matches($taskProjectText,'<File Path="([^"]+)"') | ForEach-Object {$_.Groups[1].Value})
$taskSources+=@(Get-ChildItem -LiteralPath (Join-Path $taskRoot 'src') -Recurse -File | Where-Object {$_.Extension -in '.v','.vh'} | ForEach-Object {$_.FullName.Substring($taskRoot.Length+1)})
$taskSources+=@(Get-ChildItem -LiteralPath (Join-Path $taskRoot 'vendor') -Recurse -File | Where-Object {$_.Extension -in '.v','.vh','.vhd'} | ForEach-Object {$_.FullName.Substring($taskRoot.Length+1)})
$taskRows=@{}
foreach($taskSource in ($taskSources | Select-Object -Unique)){
    $taskPath=Join-Path $taskRoot $taskSource
    $taskRows[$taskSource]=(Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash.ToLower()
}
@{target=$Target;project=$taskProject;sources=$taskRows} | ConvertTo-Json -Depth 5 | Out-File -LiteralPath (Join-Path $taskRoot "$taskBuild\build_sources.json") -Encoding utf8
Write-Output "PASS captured $Target build input hashes"
