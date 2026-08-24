param(
    [string]$AdbSerial = "YOCTO",
    [string]$TargetDir = "/data/godot/linuxcluster",
    [string]$OutputDir = ".\captures",
    [string]$QRenderDoc = "C:\Program Files\RenderDoc\qrenderdoc.exe"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$artifact = Join-Path $repoRoot "renderdoc-linux-arm64"
$adbArgs = @("-s", $AdbSerial)
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputDirPath = [IO.Path]::GetFullPath($OutputDir)
$capturePath = Join-Path $outputDirPath "LinuxCluster-$timestamp.rdc"
$statusPath = Join-Path $outputDirPath "LinuxCluster-$timestamp.log"
$deviceStdout = Join-Path $outputDirPath "LinuxCluster-$timestamp.device.stdout.log"
$deviceStderr = Join-Path $outputDirPath "LinuxCluster-$timestamp.device.stderr.log"

if (-not (Test-Path -LiteralPath (Join-Path $artifact "renderdoccmd"))) {
    throw "Extract the renderdoc-linux-arm64 artifact into $artifact first."
}

if (-not (Test-Path -LiteralPath $QRenderDoc)) {
    throw "Matching qrenderdoc.exe was not found at $QRenderDoc."
}

New-Item -ItemType Directory -Force -Path $outputDirPath | Out-Null

& adb @adbArgs shell "mkdir -p $TargetDir/.renderdoc-arm64"
& adb @adbArgs push (Join-Path $artifact "renderdoccmd") "$TargetDir/.renderdoc-arm64/renderdoccmd"
& adb @adbArgs push (Join-Path $artifact "librenderdoc.so") "$TargetDir/.renderdoc-arm64/librenderdoc.so"
& adb @adbArgs push (Join-Path $repoRoot "capture_linuxcluster.sh") "$TargetDir/.renderdoc-arm64/capture_linuxcluster.sh"
& adb @adbArgs shell "chmod +x $TargetDir/.renderdoc-arm64/renderdoccmd $TargetDir/.renderdoc-arm64/capture_linuxcluster.sh"
& adb @adbArgs shell "pkill -x LinuxCluster 2>/dev/null || true; pkill -x renderdoccmd 2>/dev/null || true"
& adb @adbArgs forward --remove "tcp:38920" 2>$null
& adb @adbArgs forward "tcp:38920" "tcp:38920"

$deviceCommand = "TARGET_DIR=$TargetDir CAPTURE_FILE=$TargetDir/LinuxCluster.rdc $TargetDir/.renderdoc-arm64/capture_linuxcluster.sh"
$deviceProcess = Start-Process adb `
    -ArgumentList (@($adbArgs) + @("shell", $deviceCommand)) `
    -RedirectStandardOutput $deviceStdout `
    -RedirectStandardError $deviceStderr `
    -WindowStyle Hidden `
    -PassThru

try {
    Write-Host "Waiting for RenderDoc target control on $AdbSerial ..."
    $targetReady = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        $listening = & adb @adbArgs shell "ss -lnt 2>/dev/null | grep -q ':38920 ' && echo ready || true"
        if (("$listening").Trim() -eq "ready") {
            $targetReady = $true
            break
        }
        if ($deviceProcess.HasExited) {
            break
        }
    }

    if (-not $targetReady) {
        throw "RenderDoc target control did not start. See $deviceStdout and $deviceStderr."
    }

    $env:RENDERDOC_TARGET_HOST = "127.0.0.1"
    $env:RENDERDOC_TARGET_PORT = "38920"
    $env:RENDERDOC_CAPTURE_OUTPUT = $capturePath
    $env:RENDERDOC_CAPTURE_STATUS = $statusPath

    $triggerProcess = Start-Process $QRenderDoc `
        -ArgumentList @("--python", (Join-Path $PSScriptRoot "trigger_capture.py")) `
        -WindowStyle Hidden `
        -Wait `
        -PassThru

    if ($triggerProcess.ExitCode -ne 0) {
        throw "RenderDoc capture trigger failed. See $statusPath."
    }
    if (-not (Test-Path -LiteralPath $capturePath)) {
        throw "RenderDoc reported success but did not create $capturePath."
    }

    Write-Host "Capture saved to $capturePath"
} finally {
    Remove-Item Env:RENDERDOC_TARGET_HOST -ErrorAction SilentlyContinue
    Remove-Item Env:RENDERDOC_TARGET_PORT -ErrorAction SilentlyContinue
    Remove-Item Env:RENDERDOC_CAPTURE_OUTPUT -ErrorAction SilentlyContinue
    Remove-Item Env:RENDERDOC_CAPTURE_STATUS -ErrorAction SilentlyContinue
    & adb @adbArgs shell "pkill -x LinuxCluster 2>/dev/null || true; pkill -x renderdoccmd 2>/dev/null || true"
    & adb @adbArgs forward --remove "tcp:38920" 2>$null
    if (-not $deviceProcess.HasExited) {
        $deviceProcess.WaitForExit(5000) | Out-Null
    }
    if (-not $deviceProcess.HasExited) {
        Stop-Process -Id $deviceProcess.Id
    }
}
