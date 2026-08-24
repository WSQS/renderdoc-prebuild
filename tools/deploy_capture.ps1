param(
    [string]$AdbSerial = "YOCTO",
    [string]$TargetDir = "/data/godot/linuxcluster",
    [string]$OutputDir = ".\captures"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$artifact = Join-Path $repoRoot "renderdoc-linux-arm64"
$adbArgs = @("-s", $AdbSerial)

if (-not (Test-Path (Join-Path $artifact "renderdoccmd"))) {
    throw "Extract the renderdoc-linux-arm64 artifact into $artifact first."
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

& adb @adbArgs shell "mkdir -p $TargetDir/.renderdoc-arm64"
& adb @adbArgs push (Join-Path $artifact "renderdoccmd") "$TargetDir/.renderdoc-arm64/renderdoccmd"
& adb @adbArgs push (Join-Path $artifact "librenderdoc.so") "$TargetDir/.renderdoc-arm64/librenderdoc.so"
& adb @adbArgs push (Join-Path $artifact "capture_linuxcluster.sh") "$TargetDir/.renderdoc-arm64/capture_linuxcluster.sh"
& adb @adbArgs shell "chmod +x $TargetDir/.renderdoc-arm64/renderdoccmd $TargetDir/.renderdoc-arm64/capture_linuxcluster.sh"
& adb @adbArgs shell "pkill -f $TargetDir/LinuxCluster || true"
& adb @adbArgs shell "rm -f $TargetDir/LinuxCluster.rdc"
& adb @adbArgs shell "TARGET_DIR=$TargetDir CAPTURE_FILE=$TargetDir/LinuxCluster.rdc $TargetDir/.renderdoc-arm64/capture_linuxcluster.sh >$TargetDir/renderdoc.log 2>&1 &"

Write-Host "Capture started on $AdbSerial. Waiting for $TargetDir/LinuxCluster.rdc ..."
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 2
    $size = (& adb @adbArgs shell "stat -c %s $TargetDir/LinuxCluster.rdc 2>/dev/null || echo 0").Trim()
    if ([int64]$size -gt 0) {
        & adb @adbArgs pull "$TargetDir/LinuxCluster.rdc" $OutputDir
        Write-Host "Capture saved to $(Join-Path (Resolve-Path $OutputDir) 'LinuxCluster.rdc')"
        exit 0
    }
}

& adb @adbArgs shell "cat $TargetDir/renderdoc.log 2>/dev/null || true"
throw "Timed out waiting for the RenderDoc capture."
