# Stage 1 Native Baseline Build

Status: `CLOSED`

## Scope

- use the downloaded official BMFLite Android source
- use the official prerequisite versions
- run the official build path without source modifications

## Environment Used

- Android SDK CMake:
  `3.22.1`
- Android NDK:
  `23.1.7779620`
- Java:
  `17`

Environment used during the build attempt:

- `ANDROID_NDK_ROOT=$HOME/Library/Android/sdk/ndk/23.1.7779620`
- `PATH=$HOME/Library/Android/sdk/cmake/3.22.1/bin:$PATH`

## Official Command Attempted

From:

- [bmf_lite/build_android.sh](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android.sh)

Executed:

```bash
cd /Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite
./build_android.sh
```

## Initial Result

The documented convenience Android path did not complete successfully.

Observed failure:

```text
fatal error: 'QnnInterface.h' file not found
```

This occurred while compiling:

- `QnnRuntime.cpp`
- `QnnTensorData.cpp`
- `QnnModel.cpp`
- `QnnControlNet_algorithm.cpp`
- `QnnControlNetPipeLine.cpp`

## Why This Matters

The official Android path currently:

- enables `BMF_LITE_ENABLE_TEX_GEN_PIC=ON` in [bmf_lite/build_android.sh](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android.sh)
- also defaults `BMF_LITE_ENABLE_TEX_GEN_PIC` to `ON` in [android/lite/src/CMakeLists.txt](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/android/lite/src/CMakeLists.txt)

At the same time, the general BMFLite root CMake defines that option as `OFF` by default in [bmf_lite/CMakeLists.txt](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/CMakeLists.txt).

So the strict Android build path is internally biased toward the QNN-backed feature path.

## Initial Blocker

The initial blocker was:

- the strict official Android build path expects QNN headers for the enabled `TEX_GEN_PIC` path

## Official-Source Resolution Evidence

Official source facts:

- the BMFLite root CMake defaults `BMF_LITE_ENABLE_TEX_GEN_PIC` to `OFF` in [bmf_lite/CMakeLists.txt](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/CMakeLists.txt)
- the Android convenience script forces it to `ON` in [bmf_lite/build_android.sh](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android.sh)
- the Android module CMake defaults it to `ON` in [android/lite/src/CMakeLists.txt](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/android/lite/src/CMakeLists.txt)
- official collaborator evidence says QNN is needed only for the Vincent chart demo:
  [Issue #159 comment](https://github.com/BabitMF/bmf/issues/159#issuecomment-2553439114)
- official collaborator evidence also documents disabling `BMF_LITE_ENABLE_TEX_GEN_PIC` in CMake:
  [Issue #159 follow-up](https://github.com/BabitMF/bmf/issues/159#issuecomment-2560790708)

## Adopted Non-QNN Path

Adopted Stage 1 closure path:

- use the official BMFLite root CMake as the Android cross-compilation entry
- keep the root default `BMF_LITE_ENABLE_TEX_GEN_PIC=OFF`
- do not patch the source tree
- enable only:
  - `BMF_LITE_ENABLE_OPENGLTEXTUREBUFFER=ON`
  - `BMF_LITE_ENABLE_CPUMEMORYBUFFER=ON`
  - `BMF_LITE_ENABLE_SUPER_RESOLUTION=ON`
  - `BMF_LITE_ENABLE_DENOISE=ON`

Executed:

```bash
cmake -S /Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite \
  -B /Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android_non_qnn_manual \
  -DCMAKE_BUILD_TYPE=Release \
  -DANDROID_STL=c++_shared \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-21 \
  -DCMAKE_TOOLCHAIN_FILE=$HOME/Library/Android/sdk/ndk/23.1.7779620/build/cmake/android.toolchain.cmake \
  -DBMF_LITE_ENABLE_OPENGLTEXTUREBUFFER=ON \
  -DBMF_LITE_ENABLE_CPUMEMORYBUFFER=ON \
  -DBMF_LITE_ENABLE_SUPER_RESOLUTION=ON \
  -DBMF_LITE_ENABLE_DENOISE=ON

cmake --build /Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android_non_qnn_manual --parallel 16
```

## Result

The non-QNN Android native baseline build completed successfully.

Produced artifacts:

- [libbmf_lite.a](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android_non_qnn_manual/lib/libbmf_lite.a)
- [test_bmf_lite_android_interface](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android_non_qnn_manual/bin/test_bmf_lite_android_interface)

Confirmed cache values:

- `BMF_LITE_ENABLE_TEX_GEN_PIC=OFF`
- `BMF_LITE_ENABLE_OPENGLTEXTUREBUFFER=ON`
- `BMF_LITE_ENABLE_CPUMEMORYBUFFER=ON`
- `BMF_LITE_ENABLE_SUPER_RESOLUTION=ON`
- `BMF_LITE_ENABLE_DENOISE=ON`

## Closure Basis

With the current project rule set:

- `Stage 1` is now closed
- the next stage is `Stage 2 - Official native real-device validation`
- real UI/transport/import integration remains outside this stage
