param([string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$taskProject = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $taskProject '_build_exhibit_videos_validation' }
$taskOutput = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskFramework = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$taskWpf = Join-Path $taskFramework 'WPF'
$taskPlayer = Join-Path $taskProject 'tools\PCVideoPlayer'
$taskExe = Join-Path $taskOutput 'verify_player.exe'
& (Join-Path $taskFramework 'csc.exe') /nologo /target:exe /platform:x64 /optimize+ /main:VideoPlaybackCheck "/out:$taskExe" "/win32manifest:$taskPlayer\player.manifest" "/resource:$taskPlayer\theme\icon.png,museum_icon" "/resource:$taskPlayer\theme\wallpaper.png,museum_wallpaper" /reference:System.dll /reference:System.Core.dll /reference:System.Xml.dll /reference:System.Xml.Linq.dll /reference:System.Xaml.dll /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/reference:$taskWpf\PresentationCore.dll" "/reference:$taskWpf\PresentationFramework.dll" "/reference:$taskWpf\WindowsBase.dll" "$taskPlayer\VideoPlayer.cs" "$PSScriptRoot\verify_player.cs"
if ($LASTEXITCODE -ne 0) { throw 'Player verification compile failed' }
$taskSelfTest = Start-Process -FilePath "$taskPlayer\MuseumPCVideoPlayer.exe" -ArgumentList '--self-test' -WindowStyle Hidden -Wait -PassThru
if ($taskSelfTest.ExitCode -ne 0) { throw 'Existing player self-test failed' }
$taskMedia = Join-Path $PSScriptRoot 'final'
$taskFiles = @(Get-ChildItem -LiteralPath $taskMedia -Filter '*.mp4' | Sort-Object Name)
if ($taskFiles.Count -ne 5) { throw 'Expected five formal films' }
$taskArgs = ($taskFiles | ForEach-Object { '"' + $_.FullName + '"' }) -join ' '
$taskTest = Start-Process -FilePath $taskExe -ArgumentList $taskArgs -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput "$taskOutput\player_validation.log" -RedirectStandardError "$taskOutput\player_validation.err"
Get-Content -LiteralPath "$taskOutput\player_validation.log" -Encoding UTF8
if ($taskTest.ExitCode -ne 0) { Get-Content -LiteralPath "$taskOutput\player_validation.err"; throw 'Player media/control verification failed' }
