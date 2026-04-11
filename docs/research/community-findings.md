# Community Findings

This document records community and issue-tracker evidence relevant to BMF/BMFLite and future Flutter integration risk.

Status: `COMPLETE FOR STAGE 0`

Primary source:

- official BMF issue tracker:
  [https://github.com/BabitMF/bmf/issues](https://github.com/BabitMF/bmf/issues)

## Key Findings

### 1. QNN Is Not Universally Required

- issue `#159`:
  [https://github.com/BabitMF/bmf/issues/159](https://github.com/BabitMF/bmf/issues/159)
- relevant comment:
  [https://github.com/BabitMF/bmf/issues/159#issuecomment-2553439114](https://github.com/BabitMF/bmf/issues/159#issuecomment-2553439114)

Finding:

- QNN is reported as needed only for the Vincent chart demo path

### 2. Android Demo GL Failures Exist

- issue `#159` includes reports of GL and denoise/demo crashes:
  [https://github.com/BabitMF/bmf/issues/159#issuecomment-2560790708](https://github.com/BabitMF/bmf/issues/159#issuecomment-2560790708)

Finding:

- emulator/device demo failures around GL/local-size compilation exist in the field

Implication:

- real-device validation remains mandatory

### 3. Graph Optimization Can Change Pipeline Behavior

- issue `#149`:
  [https://github.com/BabitMF/bmf/issues/149](https://github.com/BabitMF/bmf/issues/149)
- relevant comment:
  [https://github.com/BabitMF/bmf/issues/149#issuecomment-2491318397](https://github.com/BabitMF/bmf/issues/149#issuecomment-2491318397)

Finding:

- filters merge into one filtergraph by default
- `optimize_graph=False` was suggested when distinct nodes were desired

### 4. Over-Tuning `dist_num` Can Hurt Performance

- issue `#181`:
  [https://github.com/BabitMF/bmf/issues/181](https://github.com/BabitMF/bmf/issues/181)
- relevant discussion:
  [https://github.com/BabitMF/bmf/issues/181#issuecomment-2751360889](https://github.com/BabitMF/bmf/issues/181#issuecomment-2751360889)

Finding:

- when `dist_num` exceeds logical processor count, scheduling overhead can outweigh gains

### 5. Distributed Paths May Expose Instability

- issue `#181` includes intermittent segmentation-fault discussion:
  [https://github.com/BabitMF/bmf/issues/181#issuecomment-2760123866](https://github.com/BabitMF/bmf/issues/181#issuecomment-2760123866)

Finding:

- concurrency-heavy paths may expose bugs or instability

### 6. Thread Count Affects Memory Pressure

- issue `#126`:
  [https://github.com/BabitMF/bmf/issues/126](https://github.com/BabitMF/bmf/issues/126)
- relevant comments:
  [https://github.com/BabitMF/bmf/issues/126#issuecomment-2251869523](https://github.com/BabitMF/bmf/issues/126#issuecomment-2251869523)
  [https://github.com/BabitMF/bmf/issues/126#issuecomment-2251891601](https://github.com/BabitMF/bmf/issues/126#issuecomment-2251891601)

Finding:

- lowering decode thread count helped reduce GPU-related memory usage in the reported case

### 7. Static Linking Is Not Officially Supported

- issue `#153`:
  [https://github.com/BabitMF/bmf/issues/153](https://github.com/BabitMF/bmf/issues/153)
- relevant comment:
  [https://github.com/BabitMF/bmf/issues/153#issuecomment-2500519976](https://github.com/BabitMF/bmf/issues/153#issuecomment-2500519976)

Finding:

- dynamic-module loading remains the official expectation

### 8. Android Hardware Decode Was Mentioned By Maintainers

- issue `#104`:
  [https://github.com/BabitMF/bmf/issues/104](https://github.com/BabitMF/bmf/issues/104)
- relevant comment:
  [https://github.com/BabitMF/bmf/issues/104#issuecomment-1969029577](https://github.com/BabitMF/bmf/issues/104#issuecomment-1969029577)

Finding:

- Android hardware decode support was referenced in the issue discussion

## Flutter-Related Reality

During this stage I found no official BMF/BMFLite Flutter path in the official documentation set.

Project implication:

- any future Flutter bridge must be documented as project-owned integration work unless later official evidence says otherwise

## Practical Risk Register For InGeneBMFPro

- do not treat demo success as proof of editor-grade transport
- do not over-tune concurrency early
- do not assume graph defaults are always correct
- do not ignore device-specific GL/GPU issues
- do not claim static-link support
- do not claim official Flutter support without new primary-source evidence
*** Add File: /Users/mx/Documents/InGeneBMFPro/docs/research/source-acquisition-report.md
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

## Current Acquisition Blocker

The following official vendor-managed items are still not present in this workspace:

- QNN SDK headers
- QNN runtime libraries
- ControlNet model binaries referenced by the BMFLite README

Reason:

- the official BMFLite README routes them through Qualcomm-managed acquisition pages/tooling rather than a direct BMF-hosted public archive

Strict interpretation:

- these assets must remain listed as `missing vendor-managed assets` until they are acquired through the official flow
