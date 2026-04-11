# UI V1 Requirements

This document records the requested UI requirements for the first true-preview build.

These requirements are stage-mapped so we do not implement them in the wrong order.

Status: `APPROVED REQUIREMENTS WITH STAGE 3 SHELL LOCK COMPLETE`

## Requirement Group 1 - Remove Seeded Mock Timeline Content

Requested outcome:

- the green rectangular mock timeline clips for video/audio/text should not appear by default
- timeline content should appear only when a real video, text item, or sound item is actually inserted

Current source locations:

- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- [timeline_mock_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/models/timeline_mock_models.dart)

Correct stage:

- `Stage 3 - UI Import And Boundary Lock`

Why here:

- this is primarily a UI truthfulness issue
- it prevents fake editor content from being mistaken for real inserted media
- it does not require playback backend ownership by itself

Acceptance criteria:

- initial `_tracks` state does not contain seeded mock clips
- initial `_selectedClipId` does not point to a fake default clip
- timeline rows are empty until a real insert path is available

Implementation status:

- implemented in the imported UI reference source on `2026-04-05`
- this change is UI-shell only and does not mean the timeline is backed by real imported media yet

## Requirement Group 2 - Preview Must Stop Looking Like A Fake Canvas

Requested outcome:

- no placeholder branding text on the canvas
- no fake static preview language that looks like a real player
- when a real video is inserted, the preview should adopt the inserted media aspect ratio
- this must not alter the real source resolution

Current source locations:

- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- [preview_stage.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/preview_stage.dart)

Correct stage split:

- `Stage 3`
  - remove branded/fake placeholder copy
  - replace the current fake canvas messaging with a neutral empty preview shell
- `Stage 5`
  - real preview aspect ratio must follow real media metadata from the inserted item

Why split:

- removing deceptive fake UI is a shell cleanup task
- true aspect-ratio behavior depends on real imported asset metadata and real preview ownership

Acceptance criteria:

- no branded placeholder text remains in the default preview shell
- empty preview state is visually neutral and not misleading
- when real media drives preview, the displayed aspect ratio follows real media orientation and shape
- preview sizing must not imply a source-resolution change

Implementation status:

- shell cleanup implemented on `2026-04-05`
- branded/fake preview copy was removed
- neutral preview shell is now in place
- current UI shell now follows the selected or first visual UI asset aspect ratio
- real native preview ownership is still deferred to `Stage 5`

## Requirement Group 3 - Add Bottom Sheet Must Match The Real UX

Requested outcome:

- pressing `Add` opens a bottom sheet
- the sheet has no title
- the sheet has no close `X`
- top tabs only:
  - `Video` on the left
  - `Image` on the right
- under the tabs, a 3-column grid shows items
- tapping a video/image selects it and shows `Import` / `Add to timeline`
- pressing `Import` or `Add to timeline` inserts the item at the playhead position
- if the playhead is at `00`, the insert happens at timeline origin
- after insertion, real playback and scrub should work

Current source locations:

- [media_bottom_sheet.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/media_bottom_sheet.dart)
- [media_dock.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/media_dock.dart)
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)

Correct stage split:

- `Stage 3`
  - bottom sheet visual shell
  - tabs placement
  - no title
  - no close `X`
  - 3-column grid layout
- `Stage 6`
  - real import/add behavior
  - insertion at the playhead
  - real timeline truth
- `Stage 5`
  - real playback and scrub after insertion

Why split:

- the sheet layout itself is UI shell work
- import/add-to-timeline behavior is not truthful until the real import and timeline path exists
- playback/scrub belongs to the transport/preview stage, not the sheet stage

Acceptance criteria:

- shell stage:
  - the sheet opens with only top tabs and 3-column grid
  - no title text
  - no `X`
- real import stage:
  - pressing import/add creates a real timeline item from real media data
  - insertion position follows the playhead, including timeline origin
- real preview stage:
  - inserted media can really play and scrub

Implementation status:

- shell portion implemented on `2026-04-05`
- `Add` now opens a sheet with only `Video` and `Image` tabs
- the sheet now has no title and keeps the 3-column media grid
- the sheet now requires selecting an item before `Add to timeline`
- `Add` is disabled when non-visual tabs are active so unsupported paths do not masquerade as partially working
- current insertion still uses the UI asset library, not real gallery import
- real import and real playback remain deferred

## Strict Rule

These requirements are mandatory for the first truthful preview build, but they must not be implemented out of order.

Forbidden:

- claiming real playback while the sheet still inserts generated mock assets
- claiming real timeline truth while seeded clips still exist
- claiming real preview aspect-ratio ownership before the real preview path is integrated

Current truth statement:

- seeded timeline clips are gone from the default state
- seeded library items are treated as sample assets rather than imported media
- preview branding/fake copy is gone from the default shell
- the `Add` sheet shell matches the approved direction more closely
- shell playback remains disabled until a real transport stage exists
- the current implementation is still not a real import/playback stack

Stage status:

- the Stage 3 shell boundary requirements are satisfied
- real import, real playback, and real native preview remain deferred to later stages
