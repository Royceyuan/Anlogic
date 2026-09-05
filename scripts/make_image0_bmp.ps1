param(
    [string] $OutputPath = (Join-Path $PSScriptRoot '..\test_media\IMAGE0.BMP'),
    [ValidateRange(16, 1280)] [int] $Width = 960,
    [ValidateRange(16, 720)] [int] $Height = 540
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Generate a deterministic six-colour calibration image for the v27 BMP path.
# BMP pixels are BGR, while the colour table below is written as RGB.
$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = [System.IO.Path]::GetDirectoryName($outputFullPath)
if (![System.IO.Directory]::Exists($outputDirectory)) {
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
}

$rowStride = (($Width * 3 + 3) - (($Width * 3 + 3) % 4))
$pixelBytes = $rowStride * $Height
$bytes = New-Object byte[] (54 + $pixelBytes)

function Set-Bytes {
    param([byte[]] $Target, [int] $Offset, [byte[]] $Value)
    [System.Buffer]::BlockCopy($Value, 0, $Target, $Offset, $Value.Length)
}

# BITMAPFILEHEADER (14 bytes) + BITMAPINFOHEADER (40 bytes).
Set-Bytes $bytes 0  ([byte[]](0x42, 0x4d))
Set-Bytes $bytes 2  ([System.BitConverter]::GetBytes([uint32]$bytes.Length))
Set-Bytes $bytes 10 ([System.BitConverter]::GetBytes([uint32]54))
Set-Bytes $bytes 14 ([System.BitConverter]::GetBytes([uint32]40))
Set-Bytes $bytes 18 ([System.BitConverter]::GetBytes([int32]$Width))
# Negative height means top-down rows, matching the FPGA streaming reader.
Set-Bytes $bytes 22 ([System.BitConverter]::GetBytes([int32](-$Height)))
Set-Bytes $bytes 26 ([System.BitConverter]::GetBytes([uint16]1))
Set-Bytes $bytes 28 ([System.BitConverter]::GetBytes([uint16]24))
Set-Bytes $bytes 30 ([System.BitConverter]::GetBytes([uint32]0))
Set-Bytes $bytes 34 ([System.BitConverter]::GetBytes([uint32]$pixelBytes))
Set-Bytes $bytes 38 ([System.BitConverter]::GetBytes([int32]2835))
Set-Bytes $bytes 42 ([System.BitConverter]::GetBytes([int32]2835))

$colours = @(
    @(255, 255, 255), # white
    @(255, 255,   0), # yellow
    @(  0, 255, 255), # cyan
    @(  0, 255,   0), # green
    @(255,   0, 255), # magenta
    @(255,   0,   0)  # red
)

for ($y = 0; $y -lt $Height; $y++) {
    $rowOffset = 54 + $y * $rowStride
    $dark = $y -ge [int]($Height / 2)
    for ($x = 0; $x -lt $Width; $x++) {
        $bar = [Math]::Min(5, [int](($x * 6) / $Width))
        $r = $colours[$bar][0]
        $g = $colours[$bar][1]
        $b = $colours[$bar][2]
        if ($dark) {
            $r = [int]($r / 2)
            $g = [int]($g / 2)
            $b = [int]($b / 2)
        }
        $pixelOffset = $rowOffset + $x * 3
        $bytes[$pixelOffset + 0] = [byte]$b
        $bytes[$pixelOffset + 1] = [byte]$g
        $bytes[$pixelOffset + 2] = [byte]$r
    }
}

[System.IO.File]::WriteAllBytes($outputFullPath, $bytes)

# One small self-check: reject a malformed header before the card is used.
$check = [System.IO.File]::ReadAllBytes($outputFullPath)
if ($check.Length -ne 54 + $pixelBytes -or
    $check[0] -ne 0x42 -or $check[1] -ne 0x4d -or
    [System.BitConverter]::ToUInt32($check, 10) -ne 54 -or
    [System.BitConverter]::ToInt32($check, 18) -ne $Width -or
    [System.BitConverter]::ToInt32($check, 22) -ne -$Height -or
    [System.BitConverter]::ToUInt16($check, 28) -ne 24 -or
    [System.BitConverter]::ToUInt32($check, 30) -ne 0) {
    throw "Generated IMAGE0.BMP header is invalid."
}

Write-Host "Created $outputFullPath"
Write-Host "Format: ${Width}x${Height}, 24-bit BI_RGB, top-down"
Write-Host "Size: $($check.Length) bytes"
