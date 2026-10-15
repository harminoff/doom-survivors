[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2147483647)]
    [int]$ProcessId,
    [string]$VerifiedWindowTitle = "",
    [ValidateRange(1, 3600)]
    [int]$Seconds = 600,
    [string]$Output = ""
)

$ErrorActionPreference = "Stop"
$root = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) ".."))
$ffmpegPath = "C:\ProgramData\chocolatey\bin\ffmpeg.exe"
$ffprobePath = "C:\ProgramData\chocolatey\bin\ffprobe.exe"
if (-not (Test-Path -LiteralPath $ffmpegPath -PathType Leaf)) { throw "Required recorder is missing: $ffmpegPath" }
if (-not (Test-Path -LiteralPath $ffprobePath -PathType Leaf)) { throw "Required metadata probe is missing: $ffprobePath" }

function Get-TargetProcess {
    param([int]$Id, [string]$ExternallyVerifiedTitle)
    $target = Get-Process -Id $Id -ErrorAction Stop
    if ($target.ProcessName -notmatch "^uzdoom$") {
        throw "Process $Id is '$($target.ProcessName)', not the UZDoom target."
    }
    $title = if ($null -eq $target.MainWindowTitle) { "" } else { $target.MainWindowTitle.Trim() }
    if (-not [string]::IsNullOrWhiteSpace($ExternallyVerifiedTitle)) {
        $verified = $ExternallyVerifiedTitle.Trim()
        if (-not [string]::IsNullOrWhiteSpace($title) -and $title -ne $verified) {
            throw "Observed title '$verified' does not match process $Id title '$title'."
        }
        $uzdoomProcesses = @(Get-Process -Name "uzdoom" -ErrorAction Stop)
        if ($uzdoomProcesses.Count -ne 1 -or $uzdoomProcesses[0].Id -ne $Id) {
            throw "Externally verified title requires PID $Id to be the sole live UZDoom process."
        }
        return [pscustomobject]@{ Process = $target; Title = $verified }
    }
    if ($target.MainWindowHandle -eq 0 -or [string]::IsNullOrWhiteSpace($title)) {
        throw "UZDoom process $Id has no nonblank visible main window title."
    }
    # gdigrab resolves by title. Require that title to identify exactly this
    # live process, so another UZDoom instance can never be selected silently.
    $sameTitle = @(Get-Process -ErrorAction Stop | Where-Object {
        $_.MainWindowHandle -ne 0 -and
        -not [string]::IsNullOrWhiteSpace($_.MainWindowTitle) -and
        $_.MainWindowTitle.Trim() -eq $title
    })
    if ($sameTitle.Count -ne 1 -or $sameTitle[0].Id -ne $Id) {
        throw "Window title '$title' is not unique to live UZDoom process $Id."
    }
    return [pscustomobject]@{ Process = $target; Title = $title }
}

$target = Get-TargetProcess $ProcessId $VerifiedWindowTitle
$windowTitle = $target.Title
$processStartUtc = $target.Process.StartTime.ToUniversalTime()

if ([string]::IsNullOrWhiteSpace($Output)) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $Output = Join-Path $root "evidence\P030\p030-manual-$stamp.mp4"
} elseif (-not [System.IO.Path]::IsPathRooted($Output)) {
    $Output = Join-Path $root $Output
}
$Output = [System.IO.Path]::GetFullPath($Output)
$outputDirectory = Split-Path -Parent $Output
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$ffmpegLog = "$Output.ffmpeg.log"
$arguments = @(
    "-y", "-hide_banner", "-loglevel", "warning",
    "-f", "gdigrab", "-framerate", "60", "-draw_mouse", "1",
    "-i", "title=$windowTitle", "-t", $Seconds.ToString([Globalization.CultureInfo]::InvariantCulture),
    "-an", "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2",
    "-c:v", "libx264", "-preset", "fast", "-pix_fmt", "yuv420p", "-fps_mode", "cfr", $Output
)
# The only gdigrab input is title=<the exact validated UZDoom window>. Never
# substitute desktop, screen, or an unqualified process/window fallback.
$ffmpegOutput = & $ffmpegPath @arguments 2>&1
$ffmpegExit = $LASTEXITCODE
$ffmpegOutput | Set-Content -LiteralPath $ffmpegLog -Encoding utf8
if ($ffmpegExit -ne 0) { throw "ffmpeg failed with exit code $ffmpegExit. See $ffmpegLog" }
if (-not (Test-Path -LiteralPath $Output -PathType Leaf)) { throw "Recorder produced no video: $Output" }

$probeJson = & $ffprobePath @(
    "-v", "error", "-count_frames", "-select_streams", "v:0",
    "-show_entries", "stream=width,height,avg_frame_rate,duration,nb_frames,nb_read_frames",
    "-show_entries", "format=duration", "-of", "json", $Output
) 2>&1
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($probeJson -join ""))) {
    throw "ffprobe could not read the recorded video."
}
try { $probe = ($probeJson -join "`n") | ConvertFrom-Json } catch { throw "ffprobe returned invalid JSON." }
$stream = @($probe.streams)[0]
if ($null -eq $stream -or [int]$stream.width -le 0 -or [int]$stream.height -le 0) {
    throw "Recorded video has no valid video stream."
}
$durationText = if ($null -ne $stream.duration) { [string]$stream.duration } elseif ($null -ne $probe.format.duration) { [string]$probe.format.duration } else { "" }
[double]$duration = 0
if (-not [double]::TryParse($durationText, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$duration) -or $duration -le 0) {
    throw "ffprobe did not report a positive video duration."
}
if ($duration + 0.5 -lt $Seconds) { throw "Recorded video is too short: ${duration}s requested ${Seconds}s." }
$fpsText = [string]$stream.avg_frame_rate
$fpsParts = $fpsText -split "/"
[double]$fps = 0
if ($fpsParts.Count -eq 2) {
    [double]$fpsNumerator = 0; [double]$fpsDenominator = 0
    [double]::TryParse($fpsParts[0], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$fpsNumerator) | Out-Null
    [double]::TryParse($fpsParts[1], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$fpsDenominator) | Out-Null
    if ($fpsDenominator -gt 0) { $fps = $fpsNumerator / $fpsDenominator }
}
if ($fps -le 0) { throw "ffprobe did not report a valid average frame rate." }
$frameText = if ($null -ne $stream.nb_read_frames) { [string]$stream.nb_read_frames } else { [string]$stream.nb_frames }
[long]$frameCount = 0
if (-not [long]::TryParse($frameText, [Globalization.NumberStyles]::Integer, [Globalization.CultureInfo]::InvariantCulture, [ref]$frameCount) -or $frameCount -le 0) {
    throw "ffprobe did not report a positive frame count."
}
$expectedFrameCount = [long][math]::Round($duration * $fps)
$frameDelta = $frameCount - $expectedFrameCount

# Extract a frame after startup and reject a constant-color/blank capture.
$blankProbe = Join-Path $outputDirectory ("." + [System.IO.Path]::GetFileNameWithoutExtension($Output) + "-frame.png")
$sampleSecond = [math]::Min(30.0, [math]::Max(1.0, $duration / 2.0))
$sampleSecondText = $sampleSecond.ToString([Globalization.CultureInfo]::InvariantCulture)
$frameOutput = & $ffmpegPath @("-v", "error", "-ss", $sampleSecondText, "-i", $Output, "-frames:v", "1", "-y", $blankProbe) 2>&1
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $blankProbe -PathType Leaf)) { throw "Could not extract a validation frame from the recording." }
Add-Type -AssemblyName System.Drawing
$bitmap = [System.Drawing.Bitmap]::new($blankProbe)
try {
    $base = $bitmap.GetPixel(0, 0)
    $varied = $false
    for ($y = 0; $y -lt $bitmap.Height -and -not $varied; $y += [math]::Max(1, [int]($bitmap.Height / 12))) {
        for ($x = 0; $x -lt $bitmap.Width; $x += [math]::Max(1, [int]($bitmap.Width / 12))) {
            $pixel = $bitmap.GetPixel($x, $y)
            if ([math]::Abs($pixel.R - $base.R) + [math]::Abs($pixel.G - $base.G) + [math]::Abs($pixel.B - $base.B) -gt 3) { $varied = $true; break }
        }
    }
} finally { $bitmap.Dispose(); Remove-Item -LiteralPath $blankProbe -Force -ErrorAction SilentlyContinue }
if (-not $varied) { throw "Recorded target window is blank or constant-color." }

$packagePath = Join-Path $root "build\doom-survivors.ipk3"
$lock = Get-Content -LiteralPath (Join-Path $root "toolchain\lock.json") -Raw | ConvertFrom-Json
$enginePath = [System.IO.Path]::GetFullPath((Join-Path $root ([string]$lock.uzdoom.executable.path)))
if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) { throw "Missing package for paired identity: $packagePath" }
if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) { throw "Missing pinned engine for paired identity: $enginePath" }
$packageHash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
$engineHash = (Get-FileHash -LiteralPath $enginePath -Algorithm SHA256).Hash.ToLowerInvariant()

# Pair the capture with the newest local log that proves a manual P030 run.
$logCandidates = @()
foreach ($logRoot in @((Join-Path $root ".local"), (Join-Path $root "evidence\P030"))) {
    if (Test-Path -LiteralPath $logRoot -PathType Container) {
        $logCandidates += Get-ChildItem -LiteralPath $logRoot -Recurse -File -Filter "engine.log" -ErrorAction SilentlyContinue
    }
}
$launcherLogRoot = Join-Path $root "evidence\P030\manual"
if (Test-Path -LiteralPath $launcherLogRoot -PathType Container) {
    $logCandidates += Get-ChildItem -LiteralPath $launcherLogRoot -File -Filter "log-p030-manual-*.txt" -ErrorAction SilentlyContinue
}
$manualLogs = @()
foreach ($candidate in $logCandidates) {
    $content = Get-Content -LiteralPath $candidate.FullName -Raw -ErrorAction SilentlyContinue
    if ($candidate.LastWriteTimeUtc -ge $processStartUtc.AddSeconds(-5) -and
        $content -match "DS_P030_BOOT[^\r\n]*mode=manual" -and
        $content -match "DS_P030_RUN_START") { $manualLogs += $candidate }
}
$manualLog = $manualLogs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -eq $manualLog) { throw "No same-session manual P030 log was found for target process $ProcessId." }

$liveStatus = "ENDED"; $peakWorkingSet = $null
try {
    $live = Get-Process -Id $ProcessId -ErrorAction Stop
    if ($live.ProcessName -ne "uzdoom") { throw "target process identity changed" }
    $liveStatus = "RUNNING"
    $peakWorkingSet = [long]$live.PeakWorkingSet64
} catch { $liveStatus = "ENDED" }

$metadata = [ordered]@{
    classification = "P030_TARGET_WINDOW_CAPTURE"
    capture_source = "gdigrab:title"
    window_title = $windowTitle
    process_id = $ProcessId
    process_status_after_capture = $liveStatus
    requested_seconds = $Seconds
    actual_duration_seconds = [math]::Round($duration, 6)
    resolution = ("{0}x{1}" -f $stream.width, $stream.height)
    width = [int]$stream.width
    height = [int]$stream.height
    average_frame_rate = [math]::Round($fps, 6)
    frame_count = $frameCount
    expected_frame_count = $expectedFrameCount
    frame_delta = $frameDelta
    output = $Output
    ffmpeg_log = $ffmpegLog
    package = $packagePath
    package_sha256 = $packageHash
    engine = $enginePath
    engine_sha256 = $engineHash
    peak_working_set_bytes = $peakWorkingSet
    paired_latest_manual_log = $manualLog.FullName
    privacy_scope = "TARGET_WINDOW_ONLY"
}
$metadataPath = "$Output.json"
$metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metadataPath -Encoding utf8
Write-Host "Recorded $Seconds seconds from UZDoom PID $ProcessId ('$windowTitle')."
Write-Host "Video: $Output"
Write-Host "Metadata: $metadataPath"
