param([string]$Python = 'python')
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$taskBuild = Join-Path (Split-Path (Split-Path $PSScriptRoot)) '_build_packager_ui'
& $Python -c 'import PIL, PyInstaller; print(PIL.__version__, PyInstaller.__version__)'
if ($LASTEXITCODE -ne 0) { throw 'Requires Python with Pillow 12.3.0 and PyInstaller 6.22.3' }
& $Python -m PyInstaller --noconfirm --clean --onefile --windowed --name MuseumTFPackager --icon "$PSScriptRoot/theme/icon.ico" --add-data "$PSScriptRoot/theme;theme" --distpath "$taskBuild/dist" --workpath "$taskBuild/work" --specpath $taskBuild museum_media_packager.py
if ($LASTEXITCODE -ne 0) { throw 'Packager build failed' }
Move-Item -LiteralPath "$taskBuild/dist/MuseumTFPackager.exe" -Destination "$PSScriptRoot/MuseumTFPackager.exe" -Force
$taskHash = (Get-FileHash -LiteralPath MuseumTFPackager.exe -Algorithm SHA256).Hash
Set-Content -LiteralPath MuseumTFPackager.exe.sha256 -Encoding ascii -Value "$taskHash  MuseumTFPackager.exe"
& $Python -c 'import hashlib,json; from pathlib import Path; p=Path("offline_bundle_manifest.json"); m=json.loads(p.read_text(encoding="utf-8")); names=["MuseumTFPackager.exe","MuseumTFPackager.exe.sha256"]; m.update({n:{"bytes":Path(n).stat().st_size,"sha256":hashlib.sha256(Path(n).read_bytes()).hexdigest()} for n in names}); p.write_text(json.dumps(m,indent=2)+"\n",encoding="utf-8")'
if ($LASTEXITCODE -ne 0) { throw 'Bundle manifest update failed' }
Write-Output "PASS windowed EXE: $taskHash"
