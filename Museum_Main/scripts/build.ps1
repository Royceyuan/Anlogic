param(
    [string]$TD='D:\TD_6.2.1\bin\td_commands_prompt.exe',
    [string]$Python='D:\Anaconda\python.exe',
    [string]$ModelSim='D:\Modelsim\win64\vsim.exe',
    [switch]$CheckOnly
)
$ErrorActionPreference='Stop'
& "$PSScriptRoot/../../Museum_Secondary/scripts/build.ps1" -Target main -TD $TD -Python $Python -ModelSim $ModelSim -CheckOnly:$CheckOnly
