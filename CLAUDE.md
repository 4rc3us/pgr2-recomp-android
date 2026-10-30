# Project Gotham Racing 2 (original Xbox) - static recompilation (Android / ARM64 Port)

Goal: a native Android (ARM64 / Vulkan 1.3) port of PGR2 built with the XboxXBE-Recomp toolkit in `sdk/` (git submodule), targeting high-performance devices like the Samsung Galaxy S25 Ultra (Qualcomm Snapdragon 8 Elite / Adreno 830), while preserving headless Linux testing and the native Windows build.
Read `sdk/README.md`, `sdk/harness/README.md`, `PROGRESS.md`, `FINDINGS.md` and `ANDROID.md` at the start of every session.

## Environment
- Host Linux environment for tool building, recompilation and headless CPU verification.
- Target device: Android ARM64 (`arm64-v8a` / ARMv9-a Oryon, Adreno 830 GPU, Vulkan 1.3).
- Android NDK (r27+), Clang toolchain, CMake 3.25+, Ninja, ADB.
- Note on Android 15/16 memory: Support 16 KB page sizes (`-Wl,-z,max-page-size=16384`) in Android binaries and memory mapping (`mmap`).
- Game files are in `assets/`. Never commit, upload or paste them, or generated code.
  `assets/`, `generated/`, `build/`, `.local/` and `captures/` are git-ignored; keep it that way.
- Signatures in `sdk/xdk/*/signatures.toml` are hashes and lengths only. Never store library bytes.

## Commands
- `scripts/linux-tools.sh`   configure for Linux + build `xbe_symbols` and `xbe_recomp`
- `build/linux/xbe_symbols assets/default.xbe sdk/xdk --out config/game.toml`
     prints the XBE's XDK library versions, matches XDK functions, rewrites config/game.toml completely.
- `scripts/recompile.sh`      regenerate `generated/game`
- `scripts/harness.sh [secs] [pad] [ENV=..]`   build + run headless on Linux; e.g. `scripts/harness.sh 120 scripts/pad/boot.txt REF=600`
- `scripts/smoke.sh`          runs standard headless smoke test (title -> Instant Action -> race). Must print SMOKE OK.
- Android builds:
  - Cross-compile with Android NDK toolchain (`-DANDROID_ABI=arm64-v8a`, `-DANDROID_PLATFORM=android-31`).
  - `adb push` binaries/assets to `/data/local/tmp/pgr2/` or `/sdcard/Android/data/org.recomp.pgr2/files/`.
- Debugging:
  - Linux: `gdb` (/usr/bin/gdb). Guest memory is at 0x100000000, guest esp is at ctx+16.
  - Android: `lldb` via `adb` / ndk-gdb or logcat (`adb logcat -s pgr2`).
  - Shaders: `scripts/shadercheck.sh` to validate translated shaders.

## Android Target Plan
1. **CPU & Platform Portability (ARM64 Bring-up):**
   - Translate / adapt x86 CPU intrinsics to portable SIMDe / ARM NEON.
   - Verify guest memory mapping (`mmap`) with 4 KB guest / 16 KB host page sizes.
   - Run headless harness on ARM64 (Linux / Android shell via ADB) with CPU reference renderer.
2. **Vulkan 1.3 Graphics Backend (Adreno 830):**
   - Implement Vulkan renderer in `sdk/` matching console-accurate behaviors established in FINDINGS.md:
     - W-buffering (`D3DZB_USEW`) and far-plane clamping (`z <= w`).
     - Point sprites (`oPts` / `gl_PointSize`) for foliage/trees.
     - Depth-as-colour sampling (`kTexDepthBytes`) for depth-of-field effects.
     - Cube map reflection passes (`SetRenderTargetFast`) and visibility queries.
     - Disk pipeline cache for zero-stutter shader compilation.
3. **Android App & Platform Integration:**
   - SDL3 / NativeActivity packaging (`libPGR2.so` + APK).
   - Audio via AAudio / SDL3 at 48 kHz.
   - Display aspect ratio handling for tall screens (~19.5:9 on S25 Ultra, centered 16:9 HUD).
   - Storage isolation: virtual Xbox drives mapped to internal/external app storage.
   - Input: Gamepad support (Bluetooth / USB-C) and on-screen touch overlay.

## Working rules
- One problem at a time. After each meaningful step, add a dated entry at the top of PROGRESS.md's log
  (what changed, evidence, next step), update its Status block, and commit.
- Tag findings in `FINDINGS.md` as **[console]**, **[PGR2]**, or **[android]**.
- Game-specific fixes go in `src/game` (X86_FUNC overrides, [[hook]]/[[function]]/[[switch]] in config/pgr2.toml), not in
  generated code. SDK changes (ARM64 support, Vulkan backend, SDL Android runtime) go in the `sdk/` submodule as separate commits.
- If the same problem survives 3 genuinely different attempts, stop: write up what you tried and what you
  think is happening in PROGRESS.md, commit, and explain the blocker.
- Run `scripts/smoke.sh` before merging to `main`; it must print SMOKE OK.
- Work on one branch per task. When the task ends and everything builds, fast-forward `main` to it
  (`git merge --ff-only`) and push both.
- Never force-push. Never rewrite history.
