#!/bin/bash
# Build the headless harness executable for Android ARM64
set -euo pipefail

NDK="${ANDROID_NDK_HOME:-/home/arce/android-tools/android-ndk-r27c}"
API="35"
TARGET="aarch64-linux-android"
CXX="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/${TARGET}${API}-clang++"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
GEN="$REPO/generated/game"
OUT="$REPO/.local/android-harness"
GEN_OBJ="$OUT/gen"
mkdir -p "$GEN_OBJ" "$OUT/host"

JOBS=$(nproc)
RT="$REPO/sdk/runtime"
H="$REPO/sdk/harness"

BASE="-std=c++20 -target aarch64-linux-android35 -march=armv8.2-a+crypto+fp16+rcpc+dotprod -fno-strict-aliasing"
HOST="$BASE -O2 -g -I$REPO/src -I$RT -I$GEN -I$H -I$H/compat -DXBE_RAW_VERTICES=0 -DXBE_RENDER_THREAD=0"

echo "[1/3] Compiling generated game code for ARM64 ($JOBS jobs)..."
export CXX BASE RT GEN GEN_OBJ
ls "$GEN"/x86_recomp.*.cpp "$GEN"/x86_func_mapping.cpp | xargs -P "$JOBS" -I{} sh -c '
    o="$GEN_OBJ/$(basename {} .cpp).o"; [ "$o" -nt {} ] && exit 0
    $CXX $BASE -O1 -g0 -w -I"$RT" -I"$GEN" -c {} -o "$o.tmp" && mv "$o.tmp" "$o"'

echo "[2/3] Compiling runtime and game sources for ARM64..."
# Exclude Windows/D3D/XAudio2 sources and D3D12 render_thread
SRC=$(ls "$RT"/*/*.cpp | grep -Ev "/runtime/app/|/core/input.cpp|/core/wheel.cpp|/gpu/render_thread.cpp|/gpu/d3d12.cpp|/gpu/d3d11.cpp|/gpu/d3d_common.cpp|/audio/xaudio2.cpp")
SRC="$SRC $(ls "$REPO"/src/*/*.cpp || true)"
SRC="$SRC $(ls "$H"/*.cpp)"

stamp=$(echo "$HOST" | md5sum | cut -c1-8)
objs=()
for f in $SRC; do
    o=$OUT/host/$(echo "${f#/}" | tr / _ | sed "s/\.cpp$/.$stamp.o/"); objs+=("$o")
    [ "$o" -nt "$f" ] && continue
    echo "  compile $(basename "$f")"
    rm -f "$o"
    $CXX $HOST -c "$f" -o "$o" &
    [ "$(jobs -r | wc -l)" -ge "$JOBS" ] && wait -n
done
wait

echo "[3/3] Linking PGR2_android_cli..."
$CXX $BASE -O2 -o "$OUT/PGR2_android_cli" "${objs[@]}" "$GEN_OBJ"/*.o -static-libstdc++ -llog
echo "Built $OUT/PGR2_android_cli successfully!"
