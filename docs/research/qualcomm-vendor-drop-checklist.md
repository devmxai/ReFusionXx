# Qualcomm Vendor Drop Checklist

Use this file only for the official Qualcomm-managed assets that are not present in the public BMF archives.

Local intake root:

- [vendor_drop/qualcomm](/Users/mx/Documents/InGeneBMFPro/vendor_drop/qualcomm)

## Folder Targets

Place the downloaded/extracted files here:

- QNN SDK extracted files:
  [qnn_sdk](/Users/mx/Documents/InGeneBMFPro/vendor_drop/qualcomm/qnn_sdk)
- ControlNet model files:
  [controlnet_models](/Users/mx/Documents/InGeneBMFPro/vendor_drop/qualcomm/controlnet_models)

## Required QNN SDK Items

From the BMFLite README, the project will later need:

- `include/QNN`
- `libQnnSystem.so`
- `libQnnHtp.so`
- `libQnnHtpV75Stub.so`
- `libQnnHtpV75Skel.so`

Recommended intake rule:

- keep the original extracted QNN SDK tree under [qnn_sdk](/Users/mx/Documents/InGeneBMFPro/vendor_drop/qualcomm/qnn_sdk)
- do not rename files during download
- do not move files into the BMF tree yet

## Required ControlNet Model Items

The BMFLite README expects these final names:

- `unet.serialized.bin`
- `text_encoder.serialized.bin`
- `vae_decoder.serialized.bin`
- `controlnet.serialized.bin`

Also required:

- `vocab.txt`
- `merges.txt`

Note:

- `vocab.txt` and `merges.txt` already exist in the public BMFLite files archive inside:
  [qnnconfig](/Users/mx/Documents/InGeneBMFPro/assets/official/bmf_lite_release_files/bmf_lite_files/qnnconfig)

## Strict Intake Rules

- download only from the official Qualcomm/QPM/AI Hub paths
- do not use mirrors
- do not rename QNN SDK libraries manually
- keep the original vendor files untouched in `vendor_drop`
- after the files are present, the next step is verification and checksum recording before any copy into the engine tree

## What To Tell Me After Download

When the vendor files are ready, send:

`Vendor drop ready`

Then I will:

- inventory the files
- compute checksums
- verify naming/completeness
- update [README.md](/Users/mx/Documents/InGeneBMFPro/README.md)
- continue the official setup path without guesswork
