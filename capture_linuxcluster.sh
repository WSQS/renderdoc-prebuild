#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TARGET_DIR=${TARGET_DIR:-/data/godot/linuxcluster}
CAPTURE_FILE=${CAPTURE_FILE:-"$TARGET_DIR/LinuxCluster.rdc"}
RUNTIME=${RUNTIME:-"$TARGET_DIR/LinuxCluster"}

export LD_LIBRARY_PATH="$SCRIPT_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run}
export HOME=${HOME:-"$TARGET_DIR/home"}
export GODOT_SILENCE_ROOT_WARNING=1
mkdir -p "$HOME"

if [ -f /data/wayland_env_file ]; then
	. /data/wayland_env_file
fi

if [ -e /sys/fs/selinux/enforce ]; then
	setenforce 0 2>/dev/null || true
fi

exec "$SCRIPT_DIR/renderdoccmd" capture \
	--wait-for-exit \
	--capture-file "$CAPTURE_FILE" \
	--working-dir "$TARGET_DIR" \
	"$RUNTIME" \
	--rendering-driver opengl3
