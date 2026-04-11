# Stage 2 Native Real-Device Validation

Status: `CLOSED`

## Scope

- validate the successful non-QNN Android native baseline on one physical Android device
- use the built native test binary from Stage 1
- use the official repo validation path as the starting reference

## Validation Reference

- [ci/test_android.sh](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/ci/test_android.sh)

## Input Artifacts

- [libbmf_lite.a](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android_non_qnn_manual/lib/libbmf_lite.a)
- [test_bmf_lite_android_interface](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android_non_qnn_manual/bin/test_bmf_lite_android_interface)

## Required Device Evidence

- `adb devices` shows one physical Android device
- install or push result is recorded
- launch or execution result is recorded
- smoke-test output is recorded

## Preliminary Result

Current connected Android target detected during execution:

- `emulator-5554`

This is useful for preliminary debugging only.

It does **not** satisfy the physical-device exit gate.

Preliminary emulator execution completed with:

- `init result:-600`
- `Segmentation fault`
- exit code `139`

Captured log evidence includes:

- `GL error 0x500`
- `GL error 0x501`
- `build_program error`
- `sr.cpp, init, 304]compile program 0 error`

Interpretation:

- the native baseline still needs validation on a physical Android device
- the emulator already shows an OpenGL/program-initialization failure in the super-resolution path
- this preliminary emulator crash is recorded as a Stage 2 blocker observation, not as closure evidence

## Physical Device Closure Evidence

Physical Android device used:

- serial: `R3CT10LKLSX`
- model: `SM-S908N`
- ABI: `arm64-v8a`
- fingerprint: `samsung/b0qksx/b0q:16/BP2A.250605.031.A3/S908NKSS8GZB2:user/release-keys`

Execution result:

- `test super_resolution start`
- `init result:0`
- `processVideoFrame result = 0`
- `test super_resolution end`
- `test denoise start`
- `init result:0`
- `processVideoFrame result = 0`
- `test denoise end`
- `EXIT_CODE=0`

Generated files on device:

- `backup.jpg`
- `super_resolution.jpg`
- `denoise.jpg`

Closure judgment:

- Stage 2 is closed on physical-device native validation success
- the emulator crash remains documented as preliminary evidence only
