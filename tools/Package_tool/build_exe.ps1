param([switch]$WithAlignment)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$pythonExe = Join-Path $projectRoot '_build_media_packager_venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $pythonExe)) {
    py -3 -m venv (Join-Path $projectRoot '_build_media_packager_venv')
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create packaging environment' }
}
& $pythonExe -m pip install 'pyinstaller==6.22.3' 'pillow==12.3.0'
if ($LASTEXITCODE -ne 0) { throw 'Cannot install packaging dependencies' }
& $pythonExe -m PyInstaller --noconfirm --clean --onefile --windowed --noupx `
    --name 'MuseumTFPackager' `
    --paths (Join-Path $projectRoot 'tools') `
    --distpath $PSScriptRoot `
    --workpath (Join-Path $projectRoot '_build_media_packager/work') `
    --specpath (Join-Path $projectRoot '_build_media_packager') `
    (Join-Path $PSScriptRoot 'museum_media_packager.py')
if ($LASTEXITCODE -ne 0) { throw 'EXE build failed' }
$exeHash = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'MuseumTFPackager.exe') -Algorithm SHA256).Hash
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'MuseumTFPackager.exe.sha256'), "$exeHash  MuseumTFPackager.exe`n")
Write-Output $exeHash
if ($WithAlignment) {
    $workerPython = Join-Path $PSScriptRoot '_alignment_runtime/Scripts/python.exe'
    if (-not (Test-Path -LiteralPath $workerPython)) { throw 'Create the pinned alignment build environment described in README first' }
    & $workerPython -m PyInstaller --noconfirm --onedir --console --noupx `
        --name AlignmentWorker --collect-data whisper --collect-data tiktoken_ext `
        --copy-metadata stable-ts --copy-metadata openai-whisper `
        --exclude-module pytest --exclude-module IPython --exclude-module matplotlib `
        --exclude-module pandas --exclude-module scipy --exclude-module torchvision --exclude-module tensorflow `
        --distpath $PSScriptRoot --workpath (Join-Path $projectRoot '_build_alignment_worker/work') `
        --specpath (Join-Path $projectRoot '_build_alignment_worker') (Join-Path $PSScriptRoot 'align_worker.py')
    if ($LASTEXITCODE -ne 0) { throw 'Alignment worker build failed' }
    & $pythonExe (Join-Path $PSScriptRoot 'build_offline_bundle.py') --ffmpeg 'D:\Anaconda\envs\Deep_Learning\Library\bin\ffmpeg.exe'
    if ($LASTEXITCODE -ne 0) { throw 'Offline assembly failed' }
}
