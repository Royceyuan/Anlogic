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
Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'MuseumTFPackager.exe') -Algorithm SHA256
