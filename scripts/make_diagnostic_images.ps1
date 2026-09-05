param(
    [Parameter(Mandatory = $true)] [string] $OutputDirectory,
    [int] $Width = 160,
    [int] $Height = 120
)

if ($Width -ne 160 -or $Height -ne 120) {
    throw "The current FPGA image loader requires 160x120."
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

function Write-Rgb565Image {
    param(
        [string] $Path,
        [int] $TopColor,
        [int] $BottomColor
    )

    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create,
        [System.IO.FileAccess]::Write)
    $writer = New-Object System.IO.BinaryWriter($stream)
    for ($y = 0; $y -lt $Height; $y++) {
        $color = if ($y -lt 102) { $TopColor } else { $BottomColor }
        for ($x = 0; $x -lt $Width; $x++) {
            $writer.Write([byte](($color -shr 8) -band 0xff))
            $writer.Write([byte]($color -band 0xff))
        }
    }
    $writer.Close()
    $stream.Close()
}

# The row-102 transition is intentionally close to the 64-sector boundary:
# 102 rows * 160 pixels * 2 bytes = 32640 bytes.
Write-Rgb565Image (Join-Path $OutputDirectory 'IMAGE0_RED.BIN')   0xF800 0xF800
Write-Rgb565Image (Join-Path $OutputDirectory 'IMAGE0_GREEN.BIN') 0x07E0 0x07E0
Write-Rgb565Image (Join-Path $OutputDirectory 'IMAGE0_BLUE.BIN')  0x001F 0x001F
Write-Rgb565Image (Join-Path $OutputDirectory 'IMAGE0_WHITE.BIN') 0xFFFF 0xFFFF
Write-Rgb565Image (Join-Path $OutputDirectory 'IMAGE0_BOUNDARY.BIN') 0x07E0 0xF800

Get-ChildItem $OutputDirectory -Filter 'IMAGE0_*.BIN' | ForEach-Object {
    if ($_.Length -ne 38400) {
        throw "Unexpected size for $($_.Name): $($_.Length)"
    }
}
