param(
    [Parameter(Mandatory = $true)] [string] $OutputDirectory,
    [int] $Width = 800,
    [int] $Height = 600
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

if ($Width -ne 800 -or $Height -ne 600) {
    throw "This diagnostic pair is intended for the current 800x600 player."
}

$outputFullPath = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $outputFullPath | Out-Null

function New-DiagnosticBitmap {
    param(
        [string] $Path,
        [bool] $FrameB
    )

    $bitmap = New-Object System.Drawing.Bitmap($Width, $Height,
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::SingleBitPerPixelGridFit

        $topColor = if ($FrameB) { [System.Drawing.Color]::Blue } else { [System.Drawing.Color]::Red }
        $bottomColor = if ($FrameB) { [System.Drawing.Color]::Red } else { [System.Drawing.Color]::Blue }
        $centerColor = if ($FrameB) { [System.Drawing.Color]::Yellow } else { [System.Drawing.Color]::White }

        $graphics.Clear([System.Drawing.Color]::Black)
        $graphics.FillRectangle((New-Object System.Drawing.SolidBrush($topColor)),
            0, 0, $Width, [int]($Height / 2))
        $graphics.FillRectangle((New-Object System.Drawing.SolidBrush($bottomColor)),
            0, [int]($Height / 2), $Width, [int]($Height / 2))

        $gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(160, 255, 255, 255), 1)
        for ($x = 0; $x -lt $Width; $x += 50) {
            $graphics.DrawLine($gridPen, $x, 0, $x, $Height - 1)
        }
        for ($y = 0; $y -lt $Height; $y += 50) {
            $graphics.DrawLine($gridPen, 0, $y, $Width - 1, $y)
        }
        $gridPen.Dispose()

        $centerPen = New-Object System.Drawing.Pen($centerColor, 3)
        $graphics.DrawLine($centerPen, [int]($Width / 2), 0,
            [int]($Width / 2), $Height - 1)
        $graphics.DrawLine($centerPen, 0, [int]($Height / 2),
            $Width - 1, [int]($Height / 2))
        $centerPen.Dispose()

        $font = New-Object System.Drawing.Font("Consolas", 28,
            [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $label = if ($FrameB) { "FRAME B" } else { "FRAME A" }
        $shadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
        $foreground = New-Object System.Drawing.SolidBrush($centerColor)
        $graphics.DrawString($label, $font, $shadow, 22, 22)
        $graphics.DrawString($label, $font, $foreground, 18, 18)
        $shadow.Dispose()
        $foreground.Dispose()
        $font.Dispose()
    }
    finally {
        $graphics.Dispose()
    }

    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $bitmap.Dispose()

    # Convert the System.Drawing bottom-up BMP to the top-down stream format.
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $rowStride = (($Width * 3 + 3) - (($Width * 3 + 3) % 4))
    $pixelBytes = New-Object byte[] ($rowStride * $Height)
    for ($row = 0; $row -lt $Height; $row++) {
        [System.Buffer]::BlockCopy($bytes, 54 + ($Height - 1 - $row) * $rowStride,
            $pixelBytes, $row * $rowStride, $rowStride)
    }
    [System.Buffer]::BlockCopy([System.BitConverter]::GetBytes(-$Height), 0,
        $bytes, 22, 4)
    [System.Buffer]::BlockCopy($pixelBytes, 0, $bytes, 54, $pixelBytes.Length)
    [System.IO.File]::WriteAllBytes($Path, $bytes)
}

New-DiagnosticBitmap (Join-Path $outputFullPath "IMAGE0.BMP") $false
New-DiagnosticBitmap (Join-Path $outputFullPath "IMAGE1.BMP") $true

Get-ChildItem $outputFullPath -Filter "IMAGE?.BMP" | ForEach-Object {
    if ($_.Length -ne (54 + $Width * 3 * $Height)) {
        throw "Unexpected BMP size for $($_.FullName)."
    }
}

Write-Host "Created diagnostic pair in $outputFullPath ($Width x $Height, 24-bit top-down BMP)."
