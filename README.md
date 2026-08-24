# RenderDoc Linux ARM64

This repository builds a minimal RenderDoc command-line capture bundle for
ARM64 Linux devices such as the MT8668/auto8668p1 Yocto board.

The build is intentionally headless:

- `renderdoccmd` and `librenderdoc.so` are included;
- OpenGL ES and EGL capture support remain enabled;
- desktop OpenGL/GLX capture is disabled because the target runtime is
  Wayland + OpenGL ES;
- Qt, the desktop UI, Xlib/XCB window integration, Vulkan, and Python bindings
  are disabled;
- no device-side system libraries are overwritten.

## Build and release

This is a shell repository in the same style as
[`WSQS/libzt-prebuild`](https://github.com/WSQS/libzt-prebuild): the upstream
source is checked out by GitHub Actions and is not vendored here.

The upstream source is pinned by `RENDERDOC_REF` in
`.github/workflows/build-renderdoc-arm64.yml`. Push a new repository tag to
build and attach the bundle to that tag's GitHub Release. Use a new tag for
every build; do not reuse tags.

Recommended tag format:

```text
<renderdoc-ref>-arm64-<yyyymmdd>
```

For example:

```text
v1.45-arm64-20260824
```

`workflow_dispatch` is also available for build verification. Manual runs
upload a temporary Actions artifact but do not create a GitHub Release.

The release contains:

```text
renderdoc-linux-arm64.tar.gz
renderdoc-linux-arm64.tar.gz.sha256
```

The archive contains `renderdoccmd`, `librenderdoc.so`,
`capture_linuxcluster.sh`, source metadata, the upstream license, and
`SHA256SUMS`.

## Deploy and capture

After extracting the release archive into this repository on Windows, connect
the board with ADB and run:

```powershell
.\tools\deploy_capture.ps1 `
  -AdbSerial YOCTO `
  -TargetDir /data/godot/linuxcluster `
  -OutputDir .\captures
```

The helper pushes the RenderDoc command-line files to a private directory on
the board, starts LinuxCluster through RenderDoc, forwards the target-control
port over ADB, and uses the matching Windows `qrenderdoc.exe` Python API to
trigger and copy one frame into `captures/`.

The helper does not stop or modify unrelated Android applications. To stop a
capture manually:

```powershell
adb -s YOCTO shell "pkill -x LinuxCluster || true"
```

RenderDoc capture support is experimental on this embedded Wayland/GLES
target. The `.rdc` should be opened with a desktop RenderDoc version matching
or newer than the workflow's RenderDoc ref.
