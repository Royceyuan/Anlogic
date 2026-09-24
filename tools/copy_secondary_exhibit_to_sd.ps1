param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Z]$')]
    [string]$DriveLetter
)

$volume = Get-Volume -DriveLetter $DriveLetter -ErrorAction Stop
if ($volume.FileSystem -ne 'FAT32') {
    throw "$DriveLetter`: must be FAT32; detected $($volume.FileSystem)"
}
if ($DriveLetter -in @('C', 'D', 'E')) {
    throw "Refusing to copy to a system or project drive: $DriveLetter`:"
}

$source = Join-Path $PSScriptRoot '..\assets\secondary_exhibit_tf'
$target = "${DriveLetter}:\"
foreach ($index in 0..4) {
    $name = "IMAGE$index.BMP"
    $from = Join-Path $source $name
    $to = Join-Path $target $name
    Copy-Item -LiteralPath $from -Destination $to -Force
    if ((Get-FileHash -LiteralPath $from -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $to -Algorithm SHA256).Hash) {
        throw "Copy verification failed: $name"
    }
}
Write-Host "Five BMP files copied and SHA256 verified on $DriveLetter`:"
