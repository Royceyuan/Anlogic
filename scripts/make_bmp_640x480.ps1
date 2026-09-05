param(
    [Parameter(Mandatory = $true)] [string] $InputPath,
    [Parameter(Mandatory = $true)] [string] $OutputPath,
    [switch] $TopDown
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$expectedSize = 54 + 640 * 480 * 3
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
    $canvas = New-Object System.Drawing.Bitmap(640, 480, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    $graphics.Clear([System.Drawing.Color]::Black)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    # Fill the 4:3 BMP canvas while preserving the source aspect ratio.
    $scale = [Math]::Max(640.0 / $source.Width, 480.0 / $source.Height)
    $drawWidth = [int][Math]::Round($source.Width * $scale)
    $drawHeight = [int][Math]::Round($source.Height * $scale)
    $drawX = [int][Math]::Floor((640 - $drawWidth) / 2.0)
    $drawY = [int][Math]::Floor((480 - $drawHeight) / 2.0)
    $graphics.DrawImage($source, $drawX, $drawY, $drawWidth, $drawHeight)

    if ([System.IO.File]::Exists($outputFullPath)) {
        [System.IO.File]::Delete($outputFullPath)
    }
    $canvas.Save($outputFullPath, [System.Drawing.Imaging.ImageFormat]::Bmp)

    if ($TopDown) {
        # System.Drawing writes standard bottom-up BMP pixels. Reorder the
        # pixel array and negate biHeight to emit the equivalent top-down BMP.
        $bytes = [System.IO.File]::ReadAllBytes($outputFullPath)
        $rowBytes = 640 * 3
        $topDownPixels = New-Object byte[] ($bytes.Length - 54)
        for ($row = 0; $row -lt 480; $row++) {
            [System.Buffer]::BlockCopy($bytes, 54 + (479 - $row) * $rowBytes,
                $topDownPixels, $row * $rowBytes, $rowBytes)
        }
        [System.Buffer]::BlockCopy([System.BitConverter]::GetBytes(-480), 0,
            $bytes, 22, 4)
        [System.Buffer]::BlockCopy($topDownPixels, 0, $bytes, 54,
            $topDownPixels.Length)
        [System.IO.File]::WriteAllBytes($outputFullPath, $bytes)
    }
}
finally {
    if ($null -ne $graphics) { $graphics.Dispose() }
    if ($null -ne $canvas) { $canvas.Dispose() }
    if ($null -ne $source) { $source.Dispose() }
}

$bytes = [System.IO.File]::ReadAllBytes($outputFullPath)
$expectedHeight = if ($TopDown) { -480 } else { 480 }
if ($bytes.Length -ne $expectedSize -or
    $bytes[0] -ne 0x42 -or $bytes[1] -ne 0x4d -or
    [System.BitConverter]::ToUInt32($bytes, 10) -ne 54 -or
    [System.BitConverter]::ToUInt32($bytes, 14) -ne 40 -or
    [System.BitConverter]::ToUInt32($bytes, 18) -ne 640 -or
    [System.BitConverter]::ToInt32($bytes, 22) -ne $expectedHeight -or
    [System.BitConverter]::ToUInt16($bytes, 26) -ne 1 -or
    [System.BitConverter]::ToUInt16($bytes, 28) -ne 24 -or
    [System.BitConverter]::ToUInt32($bytes, 30) -ne 0) {
    throw "Generated BMP does not match the FPGA loader format."
}

Write-Host "Created $outputFullPath ($($bytes.Length) bytes, 640x480, 24-bit BMP, top-down=$TopDown)."
