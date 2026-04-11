# Stage 6 Real Import And Timeline Truth

## Goal

- replace generated mock asset insertion with real import/add behavior
- keep transport ownership in native Android while real device media enters the app

## Stage 6 Rules

- Android owns media-library access and runtime permissions
- Flutter hosts the approved bottom-sheet UI and timeline shell only
- video playback, seek, scrub, and preview stay bound to native `Media3`
- real mock-library insertion is forbidden in this stage
- clip editing remains disabled until real multi-clip truth is formalized

## Exit Gate

`Stage 6` may be closed only when all of the following are true:

- pressing `Add` opens the approved media bottom sheet shell
- selecting a real video or image from the device can be added to the timeline
- the inserted item appears as a real timeline clip backed by real media metadata
- imported video can rebind native preview and transport
- Flutter no longer depends on seeded mock assets as the media source

## Current Slice

The first Stage 6 slice is now implemented in:

- [MainActivity.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/MainActivity.kt)
- [DeviceMediaLibraryManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/DeviceMediaLibraryManager.kt)
- [Stage5TransportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt)
- [stage5_native_transport_controller.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage5_native_transport_controller.dart)
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- [media_bottom_sheet.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/media_bottom_sheet.dart)
- [editor_asset_item.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/models/editor_asset_item.dart)

Implemented behavior in this slice:

- Android now requests standard media-library access at runtime
- device videos and images are queried from `MediaStore`
- `Add` opens the approved `Video` / `Image` bottom-sheet shell and loads real device media into the grid
- the app now opens with no default sample video bound to preview or transport
- the media picker now renders compact portrait thumbnail cards with no per-item labels
- picker cards keep a visible selection circle and import through the approved action button only
- adding a real video now:
  - marks it as imported
  - inserts a real timeline clip
  - rebinds native `Media3` preview/transport to that imported source
  - locks the workspace canvas ratio from the first imported video only
- adding a real image now:
  - marks it as imported
  - inserts a real timeline clip
  - updates the preview shell metadata path without claiming native image playback
- later imported videos now fit inside the locked workspace canvas instead of redefining the canvas ratio
- imported media establishes preview binding at import time, not through later selection taps
- native playback is now rebuilt from the active video-track clip windows rather than treating split clips as the full original file
- delete on the main video track now closes the removed gap by rebuilding the remaining clip sequence
- split, trim, duplicate, and reorder operations now resync native playback against the current timeline truth
- picker thumbnail loading now requests higher-resolution device thumbnails for clearer image cards
- picker media queries and thumbnail extraction now run off the Android main thread
- picker thumbnails now use native byte caching plus reduced transfer sizes to lower bottom-sheet scroll lag
- picker thumbnail transport now batches requests instead of issuing one platform-channel thumbnail call per card
- picker thumbnail warmup now runs in background batches and feeds the grid from local thumbnail state instead of per-tile `FutureBuilder` fetches
- Android media queries and Android thumbnail generation now run on separate executors to avoid worker contention during sheet opening and scrolling
- picker media browsing now loads pages incrementally instead of stopping at the first local hard cap
- picker media lists now keep Android-side `DATE_ADDED DESC, _ID DESC` ordering while Flutter appends new pages without reshuffling already-rendered cards
- picker thumbnails now update through per-tile listeners instead of whole-sheet `setState()` after each warmup batch
- picker thumbnail loading now dedupes in-flight requests and retries naturally when blank cards become visible again
- picker warmup now favors page-entry and idle visible-window loading instead of repeatedly scheduling heavy work during active drag
- the bottom sheet now opens at a fixed `~68%` screen height instead of growing through drag on first open
- picker cards are now slightly smaller and visually lighter to reduce perceived scroll jitter
- the timeline now has a single-source fast path: if all active video-track clip windows belong to the same imported video, native playback keeps one prepared source and maps clip windows over it instead of rebuilding a `Media3` playlist after every edit
- the single-source fast path is intended to reduce scrub slowdown, black preview flashes, and codec churn after repeated split/delete/trim operations
- after the scrub regression review, the live scrub path was corrected again by restoring a `~16ms` Flutter dispatch cadence and keeping `EXACT` seek during drag for `sample`, `imported`, and `single-source timeline` paths
- the preview area now opens cleanly:
  - no default sample video
  - no placeholder icon/progress art in the empty canvas
  - no native source/status text chips over the preview
  - only subtle rounded corners remain around the actual video surface

## Current Remaining Blocker

The first Stage 6 import slice has now been accepted on the physical Android device for:

- opening `Add`
- granting device-media access
- loading real `Video` and `Image` items into the bottom sheet
- importing a real video into the timeline
- confirming that imported video playback, seek, and scrub work well enough for the current scope

Latest follow-up validation on the physical device now confirms:

- scrub is accepted again after the regression fix
- split/delete behavior appears broadly natural for the current slice
- newest-first ordering is now implemented from the Android query path and no longer depends on live list reshuffling in Flutter
- thumbnail fill is now materially improved after the retry/visible-window picker slice
- bottom-sheet media browsing is improved but still retains residual smoothness polish work
- the newest seam-recovery build is now accepted as the preserved working baseline for multi-clip live scrub
- the seam issue is no longer treated as the immediate blocker for saving and continuing from this version
- the timeline interaction contract now has a safer contextual-edit baseline:
  - selection remains UI-only
  - edit tools remain visible in a fixed layout
  - edit tools stay disabled by default and activate only for a selected imported clip
  - split/trim validity is now enforced when the action is pressed, not by changing toolbar activation with playhead movement
- same-source seam continuity is now improved further:
  - playback through a seam created by `split` on the same video is materially smoother than before
  - the current remaining seam risk is now treated primarily as a `cross-source` playback continuity gap, not the earlier same-source split blocker

`Stage 6` is still open because the timeline interaction contract and picker/timeline performance polish are not yet complete.

The exact remaining closure work is now tracked here:

- [stage-6-closure-checklist.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-closure-checklist.md)

## Next Slice

The next approved slice inside `Stage 6` is:

`Stage 6 Track B - Edit Correctness And Seam Continuity Recovery`

The immediate target for that slice is:

- freeze all non-preservation work outside `Track B`
- restore structural edit commit safety first
- restore runtime-real cut/delete correctness next
- fix time-exact cut geometry before any further seam polish
- then finish seam continuity at the surviving boundaries
- do not open export work before the Stage 6 closure checklist is complete

Reference:

- [stage-6-track-b-edit-correctness-and-seam-continuity-recovery.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-track-b-edit-correctness-and-seam-continuity-recovery.md)
- [stage-6-seam-boundary-stabilization.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-seam-boundary-stabilization.md)
- [stage-6-closure-checklist.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-closure-checklist.md)

Future reference only if the current-path seam ceiling is formally confirmed:

- [future-preview-architecture-composition-based-multi-clip-evaluation.md](/Users/mx/Documents/InGeneBMFPro/docs/process/future-preview-architecture-composition-based-multi-clip-evaluation.md)

## Deferred From This Slice

- real thumbnail filmstrip generation for `content://` media
- native image preview pipeline
- clip edit operations after import
- BMFLite live processing in the app runtime
- export pipeline
