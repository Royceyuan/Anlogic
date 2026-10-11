$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$taskFramework = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$taskWpf = Join-Path $taskFramework 'WPF'
& (Join-Path $taskFramework 'csc.exe') /nologo /target:winexe /platform:x64 /optimize+ /out:MuseumPCVideoPlayer.exe /win32manifest:player.manifest /win32icon:theme/icon.ico /resource:theme/icon.png,museum_icon /resource:theme/wallpaper.png,museum_wallpaper /reference:System.dll /reference:System.Core.dll /reference:System.Xml.dll /reference:System.Xml.Linq.dll /reference:System.Xaml.dll /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/reference:$taskWpf\PresentationCore.dll" "/reference:$taskWpf\PresentationFramework.dll" "/reference:$taskWpf\WindowsBase.dll" VideoPlayer.cs
if ($LASTEXITCODE -ne 0) { throw 'PC player build failed' }
$taskTest = Start-Process -FilePath (Join-Path $PSScriptRoot 'MuseumPCVideoPlayer.exe') -ArgumentList '--self-test' -WindowStyle Hidden -Wait -PassThru
if ($taskTest.ExitCode -ne 0) { throw 'UART framing self-test failed' }
$taskHash = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'MuseumPCVideoPlayer.exe') -Algorithm SHA256).Hash
Set-Content -LiteralPath (Join-Path $PSScriptRoot 'MuseumPCVideoPlayer.exe.sha256') -Encoding ascii -Value "$taskHash  MuseumPCVideoPlayer.exe"
Write-Output "PASS windowed EXE / UART framing: $taskHash"
