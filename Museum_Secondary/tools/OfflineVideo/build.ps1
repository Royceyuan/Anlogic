param([Parameter(Mandatory=$true)][string]$Python)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$taskBuild=Join-Path $taskRoot '_build_offline_media_tool'
& $Python -c 'import PIL,PyInstaller; print(PIL.__version__,PyInstaller.__version__)'
if($LASTEXITCODE -ne 0){throw 'Build environment requires Pillow and PyInstaller'}
Push-Location -LiteralPath $PSScriptRoot
try {
    & $Python -m PyInstaller --noconfirm --clean --onefile --windowed --name MuseumOfflinePackager --icon "$PSScriptRoot/theme/icon.ico" --add-data "$PSScriptRoot/mvid2.py;." --distpath "$taskBuild/dist" --workpath "$taskBuild/work" --specpath $taskBuild offline_museum_packager.py
    if($LASTEXITCODE -ne 0){throw 'Offline packager EXE build failed'}
    Copy-Item -LiteralPath "$taskBuild/dist/MuseumOfflinePackager.exe" -Destination "$PSScriptRoot/MuseumOfflinePackager.exe" -Force
    $taskDigest=(Get-FileHash -LiteralPath "$PSScriptRoot/MuseumOfflinePackager.exe").Hash
    "$($taskDigest.ToLower())  MuseumOfflinePackager.exe" | Out-File -LiteralPath "$PSScriptRoot/MuseumOfflinePackager.exe.sha256" -Encoding ascii
    Write-Output "PASS MuseumOfflinePackager.exe SHA256=$taskDigest"
} finally {Pop-Location}
