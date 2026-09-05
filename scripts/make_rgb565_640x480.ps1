param(
    [Parameter(Mandatory = $true)] [string] $InputPath,
    [Parameter(Mandatory = $true)] [string] $OutputPath,
    [ValidateSet("Crop", "Letterbox")] [string] $FitMode = "Crop"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$width = 640
$height = 480
$expectedSize = $width * $height * 2
$inputFullPath = (Resolve-Path -LiteralPath $InputPath).Path
$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = [System.IO.Path]::GetDirectoryName($outputFullPath)

if (![System.IO.Directory]::Exists($outputDirectory)) {
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
}

$source = $null
$canvas = $null
$graphics = $null
$stream = $null
$writer = $null
try {
    $source = [System.Drawing.Image]::FromFile($inputFullPath)
    $canvas = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    $graphics.Clear([System.Drawing.Color]::Black)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    if ($FitMode -eq "Crop") {
        $scale = [Math]::Max($width / $source.Width, $height / $source.Height)
    }
    else {
        $scale = [Math]::Min($width / $source.Width, $height / $source.Height)
    }
    $drawWidth = [int][Math]::Round($source.Width * $scale)
    $drawHeight = [int][Math]::Round($source.Height * $scale)
    $drawX = [int][Math]::Floor(($width - $drawWidth) / 2.0)
    $drawY = [int][Math]::Floor(($height - $drawHeight) / 2.0)
    $graphics.DrawImage($source, $drawX, $drawY, $drawWidth, $drawHeight)

    $stream = [System.IO.File]::Open($outputFullPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    $writer = New-Object System.IO.BinaryWriter($stream)
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $pixel = $canvas.GetPixel($x, $y)
            $rgb565 = (([int]$pixel.R -shr 3) -shl 11) -bor
                      (([int]$pixel.G -shr 2) -shl 5) -bor
                      ([int]$pixel.B -shr 3)
            # The FPGA loader consumes RGB565 in network (high-byte-first) order.
            $writer.Write([byte](($rgb565 -shr 8) -band 0xff))
            $writer.Write([byte]($rgb565 -band 0xff))
        }
    }
}
finally {
    if ($null -ne $writer) { $writer.Close() }
    elseif ($null -ne $stream) { $stream.Close() }
    if ($null -ne $graphics) { $graphics.Dispose() }
    if ($null -ne $canvas) { $canvas.Dispose() }
    if ($null -ne $source) { $source.Dispose() }
}

if ((Get-Item -LiteralPath $outputFullPath).Length -ne $expectedSize) {
    throw "Unexpected output size. Expected $expectedSize bytes."
}

$hash = (Get-FileHash -LiteralPath $outputFullPath -Algorithm SHA256).Hash
Write-Host "Created $outputFullPath ($expectedSize bytes, 640x480 RGB565 big-endian, SHA256 $hash)."
