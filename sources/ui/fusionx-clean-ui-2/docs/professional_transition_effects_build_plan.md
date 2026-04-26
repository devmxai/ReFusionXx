# Professional Transition Effects Build Plan

Status: active transition foundation plan.

Scope: normal clip-to-clip transitions only. AI transitions and Live Scrub engine
changes are outside this document.

## 1. Hard Rules

1. Do not touch or regress Stage 5 / Stage 5B Live Scrub.
2. Do not create a second timeline engine.
3. Every preset and every imported transition script must compile to the same
   internal transition graph.
4. Transition scripts are declarative JSON only. No JSX, JS, eval, remote
   imports, or executable shader source.
5. Presets are not closed black boxes. A preset may seed multiple editable
   lanes, and the designer must be able to modify those keyframes later.
6. Preview and export must eventually use the same evaluator. Flutter overlay
   preview is allowed only as the current safe preview step, not as final export
   parity.

## 2. Engine Principle

The engine should not try to recognize every named transition as a special
case. It should understand a compact set of transition primitives:

- `mix`
- `opacity`
- `scale`
- `positionX`
- `positionY`
- `rotation`
- `blur`
- `motionBlur`
- `colorOverlay`
- `wipe`
- `maskFeather`
- `shake`
- later: `displacement`, `rgbSplit`, `lumaMap`, `lightLeak`

Every professional transition is then a composed graph:

```text
Preset / Imported JSON
        ↓
Transition channels
        ↓
Keyframes + easing
        ↓
Transition evaluator
        ↓
Preview / Export
```

## 3. Phase Plan

### Phase 1: Primitive Preset Baseline

Build the first safe preset family using primitive compositor operations:

1. `Cross Dissolve`
2. `Fade Black`
3. `White Flash`
4. `Zoom In Camera`
5. `Blur Dissolve`
6. `Push Left`
7. `Push Right`

Acceptance:

- Each preset exists in the canonical normal transition catalog.
- Each preset loads through the JSON DSL validator.
- Each preset has stable labels, summaries, defaults, and parameters.
- Preview does not require Stage5 Live Scrub changes.

### Phase 2: Manual Primitive Lanes

Expose the same primitives in Manual Transition Scope:

- outgoing scale
- incoming scale
- outgoing slide X
- incoming slide X
- entry delay
- bridge darkness
- black mix
- white flash
- blur amount

Acceptance:

- A designer can add the primitive lane manually.
- No automatic keyframes are forced after adding a lane.
- The Key button creates real editable keyframes at the playhead.
- Moving keyframes changes the real transition evaluation.

### Phase 3: Composite Presets

Build professional named presets as editable compositions:

- `Zoom In`
- `Zoom Out`
- `Whip Pan`
- `Slide Blur`
- `Flash Zoom`
- `Blur Push`

Example `Zoom In` graph:

- outgoing scale: `100 -> 112`
- incoming scale: `118 -> 100`
- incoming opacity: `0 -> 100`
- bridge darkness: `0 -> 22 -> 0`
- blur: `0 -> 8 -> 0`
- easing: ease out / spring-safe curve

Acceptance:

- The preset expands to lanes/keyframes, not hidden behavior.
- The user can adjust timing and values after adding it.

### Phase 4: Script Compatibility

Define the public agent-facing JSON prompt and schema examples so external
agents can generate transition scripts without knowing internal Dart IDs.

Acceptance:

- Imported script validates capabilities before applying.
- Unsupported primitives fail with clear diagnostics.
- Imported script becomes editable lanes in Transition Scope.

### Phase 5: Export Parity

Move evaluation from Flutter-only preview into the shared compositor/export
contract.

Acceptance:

- Preview and export use the same transition graph semantics.
- Any preview-only preset is clearly blocked from production export.

## 4. First Implementation Slice

The first safe slice is:

1. Add canonical JSON catalog entries for Phase 1 presets.
2. Register those presets in the timeline adapter.
3. Add Flutter preview support for the new primitive presets.
4. Add the first extra manual lanes for slide, blur, and white flash.
5. Add tests proving the catalog loads all Phase 1 presets.

This gives us a real foundation without pretending that shader/export parity is
finished.

## 5. Second Implementation Slice

The second safe slice is:

1. Add composite preset definitions for:
   - `Zoom Out Camera`
   - `Whip Pan Left`
   - `Whip Pan Right`
   - `Slide Blur Left`
   - `Slide Blur Right`
   - `Flash Zoom`
2. Keep these presets on the same catalog/DSL path as Phase 1.
3. Preview them using the existing Flutter transition overlay only.
4. Keep the primitives editable in Transition Scope so future script import can
   materialize the same lanes.
5. Do not touch Live Scrub or native Stage5 files.

## 6. Third Implementation Slice

The third safe slice is transition script import for Manual Transition Scope:

1. Keep scripts declarative JSON only. No JSX, JavaScript, executable code,
   remote imports, or inline shader source.
2. Validate scripts with `NormalTransitionScriptImportService` before mutating
   timeline state.
3. Convert supported channels into the same editable manual lanes used by the
   UI:
   - `from.scale` -> `outgoingBoostScale`
   - `to.scale` -> `incomingStartScale`
   - `from.positionX` -> `outgoingOffsetX`
   - `to.positionX` -> `incomingOffsetX`
   - `from.positionY` -> `outgoingOffsetY`
   - `to.positionY` -> `incomingOffsetY`
   - `from.opacity` -> `outgoingOpacity`
   - `to.opacity` -> `incomingOpacity`
   - `from.rotation` -> `outgoingRotation`
   - `to.rotation` -> `incomingRotation`
   - `transition.blackPeak` / `transition.blackMix` -> `blackPeak`
   - `transition.whiteFlash` / `transition.flashPeak` -> `whiteFlash`
   - `transition.blurAmount` / `transition.blur` -> `blurAmount`
   - `transition.bridgeDarkness` -> `bridgeDarkness`
4. Imported lanes must remain editable: users can move keyframes, add new keys,
   and change values after import.
5. Unsupported channels must report clear warnings or errors instead of being
   silently ignored.
6. Do not touch Live Scrub, Stage5 native transport, or the playback clock while
   adding script import.

Acceptance:

- The Script action in Transition Scope opens a paste/upload JSON sheet.
- A valid JSON transition script imports into editable lanes and visible
  keyframes.
- Existing manual and preset transition flows keep working.
- Transition tests cover the script-to-lane mapping.
