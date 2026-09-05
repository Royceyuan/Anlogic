param(
    [Parameter(Mandatory = $true)] [string] $InputPath,
    [Parameter(Mandatory = $true)] [string] $OutputPath,
    [Parameter(Mandatory = $true)] [ValidateRange(16, 1280)] [int] $Width,
    [Parameter(Mandatory = $true)] [ValidateRange(16, 768)] [int] $Height,
    [ValidateSet("Letterbox", "Crop")] [string] $FitMode = "Letterbox",
    # The current streaming SDRAM writer consumes rows sequentially. A
    # top-down BMP keeps that stream order equal to the display order.
    [switch] $BottomUp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$inputFullPath = (Resolve-Path -LiteralPath $InputPath).Path
$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = [System.IO.Path]::GetDirectoryName($outputFullPath)
if (![System.IO.Directory]::Exists($outputDirectory)) {
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
}

$source = $null
$canvas = $null
$graphics = $null
try {
    $source = [System.Drawing.Image]::FromFile($inputFullPath)
    $canvas = New-Object System.Drawing.Bitmap($Width, $Height,
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    $graphics.Clear([System.Drawing.Color]::Black)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    # Letterbox preserves the complete source image. Crop fills the canvas and
    # intentionally trims the excess dimension.
    if ($FitMode -eq "Crop") {
        $scale = [Math]::Max($Width / [double]$source.Width,
                             $Height / [double]$source.Height)
    }
    else {
        $scale = [Math]::Min($Width / [double]$source.Width,
                             $Height / [double]$source.Height)
    }
    $drawWidth = [int][Math]::Round($source.Width * $scale)
    $drawHeight = [int][Math]::Round($source.Height * $scale)
    $drawX = [int][Math]::Floor(($Width - $drawWidth) / 2.0)
    $drawY = [int][Math]::Floor(($Height - $drawHeight) / 2.0)
    $graphics.DrawImage($source, $drawX, $drawY, $drawWidth, $drawHeight)

    if ([System.IO.File]::Exists($outputFullPath)) {
        [System.IO.File]::Delete($outputFullPath)
    }
    $canvas.Save($outputFullPath, [System.Drawing.Imaging.ImageFormat]::Bmp)

    if (!$BottomUp) {
        # System.Drawing writes bottom-up BMP pixels. Reverse the rows and
        # negate biHeight so the FPGA receives top row first.
        $bytes = [System.IO.File]::ReadAllBytes($outputFullPath)
        $rowStride = (($Width * 3 + 3) - (($Width * 3 + 3) % 4))
        $pixelBytes = New-Object byte[] ($rowStride * $Height)
        for ($row = 0; $row -lt $Height; $row++) {
            [System.Buffer]::BlockCopy($bytes, 54 + ($Height - 1 - $row) * $rowStride,
                $pixelBytes, $row * $rowStride, $rowStride)
        }
        [System.Buffer]::BlockCopy([System.BitConverter]::GetBytes(-$Height), 0,
            $bytes, 22, 4)
        [System.Buffer]::BlockCopy($pixelBytes, 0, $bytes, 54, $pixelBytes.Length)
        [System.IO.File]::WriteAllBytes($outputFullPath, $bytes)
    }
}
finally {
    if ($null -ne $graphics) { $graphics.Dispose() }
    if ($null -ne $canvas) { $canvas.Dispose() }
    if ($null -ne $source) { $source.Dispose() }
}

$bytes = [System.IO.File]::ReadAllBytes($outputFullPath)
$rowStride = (($Width * 3 + 3) - (($Width * 3 + 3) % 4))
$expectedSize = 54 + $rowStride * $Height
$expectedHeight = if ($BottomUp) { $Height } else { -$Height }
if ($bytes.Length -ne $expectedSize -or
    $bytes[0] -ne 0x42 -or $bytes[1] -ne 0x4d -or
    [System.BitConverter]::ToUInt32($bytes, 10) -ne 54 -or
    [System.BitConverter]::ToUInt32($bytes, 14) -ne 40 -or
    [System.BitConverter]::ToUInt32($bytes, 18) -ne $Width -or
    [System.BitConverter]::ToInt32($bytes, 22) -ne $expectedHeight -or
    [System.BitConverter]::ToUInt16($bytes, 26) -ne 1 -or
    [System.BitConverter]::ToUInt16($bytes, 28) -ne 24 -or
    [System.BitConverter]::ToUInt32($bytes, 30) -ne 0) {
    throw "Generated BMP does not match the adaptive FPGA loader format."
}

Write-Host "Created $outputFullPath ($($bytes.Length) bytes, ${Width}x${Height}, 24-bit BMP, $FitMode)."
