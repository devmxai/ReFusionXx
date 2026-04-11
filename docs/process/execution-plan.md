# InGeneBMFPro Execution Plan

This execution plan belongs to `InGeneBMFPro` only.

## Enforcement Model

- each stage is either `OPEN` or `CLOSED`
- every stage has an exit gate
- no stage transition is allowed before the current exit gate is satisfied
- README must be updated before and after every stage transition
- no “partial complete” label is allowed for a stage with unmet gate items
- if a stage requires device evidence, build success alone does not close it
- if a stage is `OPEN`, the README must state the single missing gate and the single next allowed step
- no emulator-only claim may close a device-validation stage
- no Flutter transport ownership may be assumed before the architecture stage explicitly allows it
- no undocumented BMF/BMFLite behavior may be used as closure evidence
- isolated UI-shell cleanup may be implemented early only if:
  - it does not claim real backend ownership
  - it does not change the active engine stage
  - the README states clearly that the current stage remains unchanged

## Stage 0 - Governance, Research, And Official Source Acquisition

Goal:

- define the rules
- audit the official sources
- download the official source trees
- download official public assets
- classify any gated assets accurately

Exit gate:

- official BMF/BMFLite findings documented
- UI baseline findings documented
- community findings documented
- compliance policy documented
- official UI repository downloaded into this workspace
- official BMF repository downloaded into this workspace with submodules
- exact commit and provenance recorded
- official public assets downloaded and recorded
- gated vendor-only assets documented if applicable
- scope decision made for any vendor-gated assets that are not part of the current baseline

Forbidden:

- starting builds before official source acquisition is complete
- patching source during acquisition
- copying partial trees from another folder
- masking missing vendor-gated assets as if they were downloaded
- closing the stage while a required official asset is still ambiguous

## Stage 1 - Official Native Baseline Build

Goal:

- follow official BMF/BMFLite build instructions exactly
- use the current non-QNN baseline only

Exit gate:

- prerequisites recorded
- clean build command recorded
- build artifacts recorded
- no undocumented build deviations left unexplained

## Stage 2 - Official Native Real-Device Validation

Goal:

- validate the official native baseline on real hardware

Exit gate:

- install result recorded
- launch result recorded
- smoke-test result recorded
- blockers recorded if any test fails

## Stage 3 - UI Import And Boundary Lock

Goal:

- bring the approved UI baseline into the project while keeping its mock-only status explicit

Exit gate:

- imported UI scope documented
- every mock-only area documented
- no backend claims attached to mock behavior
- seeded mock timeline clips are removed from the default initial state
- the default preview no longer shows branded/fake playback copy that could be mistaken for a real player
- the add/import bottom sheet layout matches the approved shell UX for the first real-preview build:
  - no title
  - no close `X`
  - top tabs only
  - 3-column grid

## Stage 4 - Architecture Lock

Goal:

- lock transport, preview, import, processing, and export ownership before integration

Exit gate:

- ownership table documented
- official vs project-owned responsibilities documented
- preview aspect-ratio ownership is explicitly defined
- timeline/playhead ownership is explicitly defined
- import ownership is explicitly defined

## Stage 5 - Native Transport And Preview Integration

Goal:

- connect the real playback/seek/scrub/preview path with `Media3/native` as the transport authority and Flutter as the host UI shell only

Exit gate:

- real play/pause works
- real seek works
- real scrub works
- preview is driven by the real media path
- preview aspect ratio follows real inserted media metadata without changing source resolution

## Stage 6 - Real Import And Timeline Truth

Goal:

- replace generated mock asset insertion with real import/add behavior

Exit gate:

- pressing `Add` opens the approved media bottom sheet shell
- selecting a real video/image can be imported or added to the timeline
- the inserted item appears at the playhead position, including `00` when the playhead is at the timeline origin
- timeline content is created from real imported media/text/audio data rather than seeded mock clips
- Flutter no longer relies on seeded timeline mock tracks as the source of truth

## Stage 5+ 

Later stages must be added only after the current stage is fully closed and documented.
