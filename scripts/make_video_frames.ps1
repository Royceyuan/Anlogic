param(
    [Parameter(Mandatory = $true)] [string] $VideoPath,
    [Parameter(Mandatory = $true)] [string] $OutputDirectory,
    [ValidateRange(1, 10)] [int] $FramesPerSecond = 2
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
$tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("hx4s20_frames_" + [guid]::NewGuid())
$adaptiveScript = Join-Path $PSScriptRoot "make_bmp_adaptive.ps1"

if ([System.IO.Directory]::Exists($outputFullPath) -and
    (Get-ChildItem -LiteralPath $outputFullPath -File -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
    throw "OutputDirectory must be empty so existing frame files are not overwritten: $outputFullPath"
}

New-Item -ItemType Directory -Force -Path $outputFullPath, $tempDirectory | Out-Null
try {
    # Decode offline only. The active FPGA design still loads IMAGE0/IMAGE1,
    # so these files are a verified input format, not a runtime player yet.
    & $ffmpeg.Source -hide_banner -loglevel error -i $videoFullPath `
        -vf "fps=$FramesPerSecond" -frames:v 1000 `
        (Join-Path $tempDirectory "raw_%04d.png")
    if ($LASTEXITCODE -ne 0) { throw "FFmpeg frame extraction failed." }

    $rawFrames = @(Get-ChildItem -LiteralPath $tempDirectory -Filter "raw_*.png" | Sort-Object Name)
    if ($rawFrames.Count -eq 0) { throw "The video produced no frames." }

    $frameIndex = 0
    foreach ($rawFrame in $rawFrames) {
        # FAT 8.3 permits at most eight base-name characters: FRAME000.BMP.
        $outputPath = Join-Path $outputFullPath ("FRAME{0:D3}.BMP" -f $frameIndex)
        & powershell -ExecutionPolicy Bypass -File $adaptiveScript `
            -InputPath $rawFrame.FullName -OutputPath $outputPath -Width 800 -Height 600 -FitMode Letterbox
        if ($LASTEXITCODE -ne 0) { throw "BMP conversion failed for $($rawFrame.Name)." }
        $frameIndex++
    }

    $totalMiB = [Math]::Round(((Get-ChildItem -LiteralPath $outputFullPath -File | Measure-Object Length -Sum).Sum / 1MB), 1)
    Write-Host "Created $frameIndex FPGA-ready BMP frames in $outputFullPath ($totalMiB MiB, $FramesPerSecond fps source sequence)."
}
finally {
    if ([System.IO.Directory]::Exists($tempDirectory)) {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force
    }
}
