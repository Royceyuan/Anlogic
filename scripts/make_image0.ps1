param(
    [Parameter(Mandatory = $true)] [string] $InputPath,
    [Parameter(Mandatory = $true)] [string] $OutputPath,
    [int] $Width = 160,
    [int] $Height = 120
)

Add-Type -AssemblyName System.Drawing

$source = [System.Drawing.Image]::FromFile((Resolve-Path $InputPath))
$canvas = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$graphics = [System.Drawing.Graphics]::FromImage($canvas)
$graphics.Clear([System.Drawing.Color]::Black)
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

# Fill the 4:3 framebuffer while preserving aspect ratio. This crops only the
# excess left/right area for the certificate instead of adding black bars.
$scale = [Math]::Max($Width / $source.Width, $Height / $source.Height)
$drawWidth = [int] [Math]::Round($source.Width * $scale)
$drawHeight = [int] [Math]::Round($source.Height * $scale)
$drawX = [int] (($Width - $drawWidth) / 2)
$drawY = [int] (($Height - $drawHeight) / 2)
$graphics.DrawImage($source, $drawX, $drawY, $drawWidth, $drawHeight)

$stream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
$writer = New-Object System.IO.BinaryWriter($stream)
for ($y = 0; $y -lt $Height; $y++) {
    for ($x = 0; $x -lt $Width; $x++) {
        $pixel = $canvas.GetPixel($x, $y)
        # GetPixel returns Byte values. Convert before shifting so RGB565 bits do not overflow at 8 bits.
        $red5 = ([int]$pixel.R) -shr 3
        $green6 = ([int]$pixel.G) -shr 2
        $blue5 = ([int]$pixel.B) -shr 3
        $rgb565 = ($red5 -shl 11) -bor ($green6 -shl 5) -bor $blue5
        $writer.Write([byte](($rgb565 -shr 8) -band 0xff))
        $writer.Write([byte]($rgb565 -band 0xff))
    }
}
$writer.Close()
$graphics.Dispose()
$canvas.Dispose()
$source.Dispose()

if ((Get-Item $OutputPath).Length -ne ($Width * $Height * 2)) {
    throw "Unexpected output size."
}
