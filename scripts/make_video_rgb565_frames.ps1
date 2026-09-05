param(
    [Parameter(Mandatory = $true)] [string] $VideoPath,
    [Parameter(Mandatory = $true)] [string] $OutputDirectory,
    [ValidateRange(1, 10)] [int] $FramesPerSecond = 2,
    [ValidateRange(1, 16)] [int] $FrameCount = 10,
    [ValidateSet("Crop", "Letterbox")] [string] $FitMode = "Crop"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($null -eq $ffmpeg) {
    $bundledFfmpeg = Get-ChildItem -LiteralPath "D:\Anlogic_information\tools\ffmpeg" -Filter "ffmpeg.exe" -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -ne $bundledFfmpeg) {
        $ffmpeg = [PSCustomObject]@{ Source = $bundledFfmpeg.FullName }
    }
}
if ($null -eq $ffmpeg) {
    throw "FFmpeg was not found. Install FFmpeg, reopen PowerShell, then run this script again."
}

$videoFullPath = (Resolve-Path -LiteralPath $VideoPath).Path
$outputFullPath = [System.IO.Path]::GetFullPath($OutputDirectory)
$tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("hx4s20_rgb565_" + [guid]::NewGuid())
$rgbScript = Join-Path $PSScriptRoot "make_rgb565_640x480.ps1"

if ([System.IO.Directory]::Exists($outputFullPath) -and
    (Get-ChildItem -LiteralPath $outputFullPath -File -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
    throw "OutputDirectory must be empty so existing frame files are not overwritten: $outputFullPath"
}

New-Item -ItemType Directory -Force -Path $outputFullPath, $tempDirectory | Out-Null
try {
    & $ffmpeg.Source -hide_banner -loglevel error -i $videoFullPath `
        -vf "fps=$FramesPerSecond" -frames:v $FrameCount `
        (Join-Path $tempDirectory "raw_%03d.png")
    if ($LASTEXITCODE -ne 0) { throw "FFmpeg frame extraction failed." }

    $rawFrames = @(Get-ChildItem -LiteralPath $tempDirectory -Filter "raw_*.png" | Sort-Object Name)
    if ($rawFrames.Count -eq 0) { throw "The video produced no frames." }

    $frameIndex = 0
    foreach ($rawFrame in $rawFrames) {
        $outputPath = Join-Path $outputFullPath ("FRAME{0:D3}.BIN" -f $frameIndex)
        & powershell -ExecutionPolicy Bypass -File $rgbScript `
            -InputPath $rawFrame.FullName -OutputPath $outputPath -FitMode $FitMode
        if ($LASTEXITCODE -ne 0) { throw "RGB565 conversion failed for $($rawFrame.Name)." }
        $frameIndex++
    }
}
finally {
    if ([System.IO.Directory]::Exists($tempDirectory)) {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force
    }
}

$expectedSize = 640 * 480 * 2
$badFrames = @(Get-ChildItem -LiteralPath $outputFullPath -File | Where-Object { $_.Length -ne $expectedSize })
if ($badFrames.Count -ne 0 -or $frameIndex -ne $rawFrames.Count) {
    throw "Generated frame set is invalid. Expected $expectedSize bytes per frame."
}

$totalMiB = [Math]::Round(((Get-ChildItem -LiteralPath $outputFullPath -File | Measure-Object Length -Sum).Sum / 1MB), 1)
Write-Host "Created $frameIndex RGB565 BIN frames in $outputFullPath ($totalMiB MiB, 640x480, big-endian)."
