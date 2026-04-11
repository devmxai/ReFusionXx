# BMF Official Baseline

This document records only official-source findings and exact blockers discovered during source acquisition.

Status: `COMPLETE FOR STAGE 0`

## Official Sources Reviewed

- BMF repository:
  [https://github.com/BabitMF/bmf](https://github.com/BabitMF/bmf)
- BMF docs:
  [https://babitmf.github.io/docs/bmf/](https://babitmf.github.io/docs/bmf/)
- BMF install docs:
  [https://babitmf.github.io/docs/bmf/getting_started_yourself/install/](https://babitmf.github.io/docs/bmf/getting_started_yourself/install/)
- BMFLite README:
  [https://github.com/BabitMF/bmf/blob/master/bmf_lite/README.md](https://github.com/BabitMF/bmf/blob/master/bmf_lite/README.md)

## Official Language And Platform Support

- BMF officially documents Python, C++, and Go APIs
- BMF source-build docs focus on Linux, Windows, and macOS
- BMFLite is publicly documented for Android and iOS, and the repository layout also exposes OHOS-related material

Inference from the official materials checked:

- I found no official Flutter or Dart API surface in the reviewed BMF/BMFLite docs or repository documentation

## Official Build Requirements

### BMF

From the official install docs:

- `CMake >= 3.5`
- `CMake >= 3.17` if CUDA is enabled
- FFmpeg versions `4.x / 5.x`, with `4.4` recommended

### BMFLite Android

From the official BMFLite README:

- `CMake 3.22.1` in Android Studio SDK Manager
- `cmake -version` should not be lower than `3.20.4`
- `NDK >= r23`
- `JDK >= 11`
- Android build commands:
  - `./build_android.sh`
  - or `cd android && ./gradlew :lite:assembleRelease`

### BMFLite iOS

From the official BMFLite README:

- Xcode
- `CMake >= 3.20.4`
- iOS build command:
  - `bash build_ios.sh`

## Officially Documented Public Assets

Downloaded into this project:

- [files.tar.gz](/Users/mx/Documents/InGeneBMFPro/assets/official/files.tar.gz)
- [bmf_lite_files.tar.gz](/Users/mx/Documents/InGeneBMFPro/assets/official/bmf_lite_files.tar.gz)

The BMFLite public archive contains:

- `test.mp4`
- `test.jpg`
- `test-canny.png`
- `qnnconfig/merges.txt`
- `qnnconfig/vocab.txt`

## Official Vendor-Gated Assets

From the BMFLite README, the Android QNN path still depends on vendor-managed acquisition steps:

- Qualcomm ID login
- Qualcomm Package Manager
- Qualcomm QNN SDK extraction
- QNN runtime libraries
- ControlNet model binaries

Relevant official links cited by the BMFLite README:

- [https://myaccount.qualcomm.com/login](https://myaccount.qualcomm.com/login)
- [https://qpm.qualcomm.com/](https://qpm.qualcomm.com/)
- [https://aihub.qualcomm.com/models/controlnet_quantized](https://aihub.qualcomm.com/models/controlnet_quantized)

Strict project interpretation:

- these assets must be treated as official-but-external vendor assets
- they must not be marked downloaded unless the official vendor-managed flow is actually completed
- they are not part of the current non-QNN baseline scope

## Current Scope Decision

For `InGeneBMFPro` stage planning:

- `QNN / ControlNet / Vincent chart` is explicitly out of current baseline scope
- the current baseline target is the official non-QNN BMFLite path
- if QNN-backed features are needed later, they must return as a dedicated future stage with official vendor-managed acquisition

## Contradictions And Drift To Watch

- BMFLite README uses `SRC/main/assets` casing in examples, while the repository layout uses `src`
- `build_android.sh` and Android Gradle module settings are not perfectly aligned on Android SDK levels
- BMF documentation contains some platform/version drift between overview messaging and detailed install pages
- the BMFLite root CMake sets `BMF_LITE_ENABLE_TEX_GEN_PIC` to `OFF` by default, while:
  - [bmf_lite/build_android.sh](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android.sh) passes it as `ON`
  - [android/lite/src/CMakeLists.txt](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/android/lite/src/CMakeLists.txt) defaults it to `ON`

## Confirmed Stage 1 Build Blocker

Using the official Android build path with the official prerequisite versions led to a compile failure on:

```text
fatal error: 'QnnInterface.h' file not found
```

This confirms that the strict Android build path currently pulls `QNNControlNet` into the baseline build unless the path is changed.

## Stage 1 Resolution

Further official-source-backed review established:

- the root BMFLite CMake keeps `BMF_LITE_ENABLE_TEX_GEN_PIC` `OFF` by default
- the Android convenience paths are what force or default it to `ON`
- official collaborator guidance on [Issue #159](https://github.com/BabitMF/bmf/issues/159) states that QNN is needed only for the Vincent chart demo and shows disabling `BMF_LITE_ENABLE_TEX_GEN_PIC` in CMake

Project conclusion:

- the adopted non-QNN Android baseline path for `InGeneBMFPro` is the BMFLite root-CMake Android cross-build without enabling `TEX_GEN_PIC`
- this path successfully built the Stage 1 native artifacts without patching the source tree

These are not reasons to invent custom behavior. They are reasons to prefer the primary install docs and to record any project-local deviation explicitly if one ever becomes unavoidable.
