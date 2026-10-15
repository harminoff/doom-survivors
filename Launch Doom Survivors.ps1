[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$InputTrace,
    [switch]$SkipMenu,
    [ValidateSet(0, 1)]
    [int]$TestMinutes = 0
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$python = Join-Path $root ".venv\Scripts\python.exe"
$roomSpec = Join-Path $root "maps\source\mad-forest\room.json"
$package = Join-Path $root "build\doom-survivors.ipk3"

if (-not (Test-Path -LiteralPath $python)) {
    throw "The project virtual environment is missing: $python"
}
if (-not (Test-Path -LiteralPath $roomSpec)) {
    throw "The P030 room specification is missing: $roomSpec"
}
if (-not $SkipBuild) {
    & $python (Join-Path $root "tools\build.py") --stages
    if ($LASTEXITCODE -ne 0) { throw "P030 package build failed with exit code $LASTEXITCODE" }
}
if (-not (Test-Path -LiteralPath $package)) {
    throw "The packaged IWAD is missing: $package"
}

$lock = Get-Content -LiteralPath (Join-Path $root "toolchain\lock.json") -Raw | ConvertFrom-Json
$executable = Join-Path $root $lock.uzdoom.executable.path
if (-not (Test-Path -LiteralPath $executable)) {
    throw "The pinned UZDoom executable is missing: $executable"
}

$profile = Join-Path $root ".local\p030-manual"
$evidence = Join-Path $root "evidence\P030\manual"
New-Item -ItemType Directory -Force -Path $profile, $evidence | Out-Null
$configPath = Join-Path $profile "config.ini"
$config = @"
[LastRun]
Version=230
[IWADSearch.Directories]
Path=.
[FileSearch.Directories]
Path=.
[GlobalSettings]
vid_fullscreen=false
win_w=1280
win_h=720
vid_defwidth=1280
vid_defheight=720
vid_preferbackend=1
vid_vsync=false
vid_maxfps=60
vid_activeinbackground=false
vid_lowerinbackground=false
screenblocks=11
screenshot_dir=$($evidence.Replace('\', '/'))
"@
# Seed the persistent profile once.  Durable gameplay CVARs written by UZDoom
# must survive later launches of this same player-facing entry point.
if (-not (Test-Path -LiteralPath $configPath)) {
    Set-Content -LiteralPath $configPath -Value $config -Encoding utf8
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logBase = "p030-manual-$stamp"
$logPath = Join-Path $evidence "log-$logBase.txt"
$inputTraceValue = if ($InputTrace) { "1" } else { "0" }
function Quote-NativeArgument([string]$value) {
    return '"' + $value.Replace('"', '\"') + '"'
}

$arguments = @(
    "-iwad", (Quote-NativeArgument $package),
    "-config", (Quote-NativeArgument $configPath),
    "-savedir", (Quote-NativeArgument $profile),
    "-noautoload", "-noautoexec", "-noextras",
    "+joy_dinput", "false",   # DirectInput controller scan can stall startup ~20 s; XInput pads still work
    "-width", "1280", "-height", "720",
    "+vid_fullscreen", "false",
    "+vid_preferbackend", "0",
    "+vid_activeinbackground", "false",
    "+vid_lowerinbackground", "false",
    "+vid_maxfps", "60",
    "+screenblocks", "11",
    "+enablescriptscreenshot", "true",
    "+screenshot_dir", (Quote-NativeArgument $evidence),
    "+logfile", $logBase,
    "+con_notifytime", "0",
    "+chase_dist", "120",
    "+chase_height", "30",
    "+lookspring", "0",
    "+set", "ds_p030_mode", "manual",
    "+set", "ds_p030_speed", "1",
    "+set", "ds_p030_telemetry", "0",
    "+set", "ds_p030_input_trace", $inputTraceValue
)
$durationTics = 63000
if ($TestMinutes -gt 0) { $durationTics = $TestMinutes * 60 * 35 }
$arguments += @("+set", "ds_p030_duration_tics", [string]$durationTics)
# The title screen opens the game shell (main menu -> character -> stage).
# -SkipMenu starts Mad Forest directly.
$arguments += @("+set", "ds_shell_autoopen", "1")
if ($SkipMenu) { $arguments += @("+map", "MAP16") }
$process = Start-Process -FilePath $executable -ArgumentList $arguments -WorkingDirectory $evidence -PassThru
Write-Host "Doom Survivors P030 started (PID $($process.Id))."
Write-Host "Pick Start, a character and a stage. WASD moves, mouse looks, Enter retries results, and Escape opens the main menu."
if ($TestMinutes -gt 0) { Write-Host "Manual test duration: $TestMinutes minute(s) ($durationTics source tics)." }
else { Write-Host "Mad Forest: full 30:00 stage; the Reaper arrives at 30:00." }
Write-Host "Prototype diagnostic art is used for this P030 gameplay slice."
Write-Host "Manual log: $logPath"
if ($InputTrace) { Write-Host "Native keyboard/mouse command and pose tracing is enabled for this run." }
