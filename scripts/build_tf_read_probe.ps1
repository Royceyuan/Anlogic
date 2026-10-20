param(
    [string]$TD='D:\TD_6.2.1\bin\td_commands_prompt.exe',
    [string]$Iverilog='D:\iverilog\bin\iverilog.exe',
    [string]$Vvp='D:\iverilog\bin\vvp.exe'
)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Push-Location -LiteralPath $taskRoot
try {
    $taskBuild=Join-Path $taskRoot '_build_tf_read_probe'
    New-Item -ItemType Directory -Path $taskBuild -Force | Out-Null
    foreach($taskDelay in @(0,14)) {
        & $Iverilog -g2012 -Wall -s tb_sd_native_read -P "tb_sd_native_read.CARD_DELAY_NS=$taskDelay" -o "$taskBuild\sd_native.vvp" src/storage/sd_native_command.v src/storage/sd_native_data_rx.v src/storage/sd_native_read.v sim/tb_sd_native_read.v
        if($LASTEXITCODE -ne 0) {throw 'SD simulation compilation failed'}
        & $Vvp "$taskBuild\sd_native.vvp" | Tee-Object -FilePath "$taskBuild\simulation_${taskDelay}ns.log"
        if($LASTEXITCODE -ne 0) {throw 'SD simulation failed'}
    }
    & $TD './scripts/build_tf_read_probe.tcl' *> "$taskBuild\console.log"
    if($LASTEXITCODE -ne 0) {throw 'SD probe synthesis/route failed'}
    & $TD './scripts/generate_tf_read_probe.tcl' *> "$taskBuild\bitgen.log"
    if($LASTEXITCODE -ne 0 -or -not (Select-String -LiteralPath "$taskBuild\bitgen.log" -Pattern 'Generate bits file')) {throw 'SD probe bit generation refused or failed'}
    Get-FileHash -LiteralPath "$taskBuild\secondary_tf_read_probe.bit"
} finally {Pop-Location}
