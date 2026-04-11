# Source Acquisition Report

Status: `COMPLETE FOR CURRENT STAGE WORK`

## Local Source Trees

### UI Reference

- local path:
  [sources/ui/fusionx-clean-ui-2](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2)
- origin:
  `https://github.com/devmxai/fusionx-clean-ui-2`
- commit:
  `7990d4acf2d60cb37ecdb872d7733da2cf0ad975`
- size:
  `4.7M`

### Official BMF

- local path:
  [sources/engine/bmf-official](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official)
- origin:
  `https://github.com/BabitMF/bmf`
- commit:
  `7d5c79bde80cbaffb7c9aa99f0593c4c490ceebe`
- size:
  `104M`
- `.gitmodules` present:
  `no`

## Official Public Asset Archives

### files.tar.gz

- local path:
  [files.tar.gz](/Users/mx/Documents/InGeneBMFPro/assets/official/files.tar.gz)
- extracted path:
  [bmf-release-files](/Users/mx/Documents/InGeneBMFPro/assets/official/bmf-release-files)
- size:
  `192M`
- sha1:
  `de4e8a8a17a00083d6260bb55ad43c125b672fb2`

### bmf_lite_files.tar.gz

- local path:
  [bmf_lite_files.tar.gz](/Users/mx/Documents/InGeneBMFPro/assets/official/bmf_lite_files.tar.gz)
- extracted path:
  [bmf_lite_release_files](/Users/mx/Documents/InGeneBMFPro/assets/official/bmf_lite_release_files)
- size:
  `2.3M`
- sha1:
  `9daec79efab10fcd2736a3503e3ffa0b44e828bd`

## Extracted BMFLite Public Files Confirmed

- [test.mp4](/Users/mx/Documents/InGeneBMFPro/assets/official/bmf_lite_release_files/bmf_lite_files/test.mp4)
- [test.jpg](/Users/mx/Documents/InGeneBMFPro/assets/official/bmf_lite_release_files/bmf_lite_files/test.jpg)
- [test-canny.png](/Users/mx/Documents/InGeneBMFPro/assets/official/bmf_lite_release_files/bmf_lite_files/test-canny.png)
- [merges.txt](/Users/mx/Documents/InGeneBMFPro/assets/official/bmf_lite_release_files/bmf_lite_files/qnnconfig/merges.txt)
- [vocab.txt](/Users/mx/Documents/InGeneBMFPro/assets/official/bmf_lite_release_files/bmf_lite_files/qnnconfig/vocab.txt)

## Vendor-Gated Assets Not In Current Baseline Scope

The following official vendor-managed items are still not present in this workspace:

- QNN SDK headers
- QNN runtime libraries
- ControlNet model binaries referenced by the BMFLite README

Reason:

- the official BMFLite README routes them through Qualcomm-managed acquisition pages/tooling rather than a direct BMF-hosted public archive

Strict interpretation:

- these assets remain outside the current non-QNN baseline scope
- if they are needed later, they must be acquired through the official Qualcomm-managed flow and recorded in a future stage
