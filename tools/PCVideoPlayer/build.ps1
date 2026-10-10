$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$taskFramework = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$taskWpf = Join-Path $taskFramework 'WPF'
& (Join-Path $taskFramework 'csc.exe') /nologo /target:winexe /platform:x64 /optimize+ /out:MuseumPCVideoPlayer.exe /win32manifest:player.manifest /reference:System.dll /reference:System.Core.dll /reference:System.Xaml.dll /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/reference:$taskWpf\PresentationCore.dll" "/reference:$taskWpf\PresentationFramework.dll" "/reference:$taskWpf\WindowsBase.dll" VideoPlayer.cs
if ($LASTEXITCODE -ne 0) { throw 'PC player build failed' }
$taskTest = Start-Process -FilePath (Join-Path $PSScriptRoot 'MuseumPCVideoPlayer.exe') -ArgumentList '--self-test' -WindowStyle Hidden -Wait -PassThru
if ($taskTest.ExitCode -ne 0) { throw 'UART framing self-test failed' }
Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'MuseumPCVideoPlayer.exe') -Algorithm SHA256
