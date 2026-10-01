param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Z]$')]
    [string]$DriveLetter
)

if ($DriveLetter -in @('C', 'D', 'E')) {
    throw "Refusing to copy to a system or project drive: $DriveLetter`:"
}
$volume = Get-Volume -DriveLetter $DriveLetter -ErrorAction Stop
if ($volume.FileSystem -ne 'FAT32') {
    throw "$DriveLetter`: must be FAT32; detected $($volume.FileSystem)"
}

$images = Join-Path $PSScriptRoot '..\assets\secondary_exhibit_720p_tf'
$emergency = Join-Path $PSScriptRoot '..\assets\secondary_emergency_720p_v2\IMAGEA.BMP'
$target = "${DriveLetter}:\"
foreach ($name in @((0..9 | ForEach-Object { "IMAGE$_.BMP" }) + 'IMAGEA.BMP')) {
    $from = if ($name -eq 'IMAGEA.BMP') { $emergency } else { Join-Path $images $name }
    $to = Join-Path $target $name
    Copy-Item -LiteralPath $from -Destination $to -Force
    if ((Get-FileHash -LiteralPath $from -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $to -Algorithm SHA256).Hash) {
        throw "Copy verification failed: $name"
    }
}
Write-Host "Eleven native 720p BMP files copied and SHA256 verified on $DriveLetter`:"
