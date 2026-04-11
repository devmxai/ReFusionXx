# BETA10

## Status

- snapshot type: `beta tag`
- repository: `https://github.com/devmxai/FBMFX`
- tag target branch at creation time: `codex/timeline-motion-progress`
- current project stage: `Stage 6 - Real Import And Timeline Truth`
- stage status: `OPEN`

## Scope

`BETA10` preserves the latest local editor-facing baseline reached so far in the
isolated `InGeneBMFPro` workspace.

This beta includes the current accepted combined snapshot of:

- real import and native preview ownership already established in `Stage 6`
- Professional Motion text preset import through the dedicated `Text` flow
- custom text preset JSON validation and import normalization
- canvas text preview rendering through the local motion runtime adapter
- text edit entry from the timeline through double-tap
- text edit bottom sheet and direct transform overlay during active text edit
- timeline trim mode gated behind one `Trim` tool instead of always-on trim
  chrome
- internal left/right trim handles with trim-only interaction mode
- unified timeline header rendering so the left time readout and ruler labels
  share one header path
- latest scrub refinement closer to native ownership

## Validation Snapshot

The latest local validation completed for this beta snapshot is:

- `flutter analyze`
- `./gradlew app:compileDebugKotlin`
- `flutter build apk --debug`
- latest debug APK reinstall on physical device `R3CT10LKLSX`
- latest app launch confirmation on
  `com.fusionx.fusionx_clean_ui_2/.MainActivity`

## Known Open Area

`BETA10` does **not** close `Stage 6`.

The strongest remaining open area after this beta snapshot is final timeline
interaction polish, especially continued scrub/trim/zoom refinement under the
still-open `Stage 6` contract.
