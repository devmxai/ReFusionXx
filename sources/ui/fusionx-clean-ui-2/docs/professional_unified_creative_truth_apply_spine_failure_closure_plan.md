# Professional Unified Creative Truth Apply Spine Failure Closure Plan

Short name: `PUCTAS-FC`

Parent plan: `professional_unified_creative_truth_apply_spine_plan.md`

Status: corrective diagnostic and execution gate

Date: 2026-05-14

## 0. Decision

Do not create a disconnected replacement plan.

The correct action is to keep `PUCTAS` as the parent architecture and add this
failure-closure plan as the mandatory execution addendum for the current live
MCP failures.

Reason:

```text
The current bugs are not separate feature bugs.
They are proof that the PUCTAS spine is not fully enforced yet.
```

Therefore the implementation must not patch background, text, motion, and
latency as isolated fixes. It must close the bypasses that still let MCP write
through old partial paths.

## 1. Current Failing Symptoms

The latest device and code review confirmed these live failures:

1. MCP creates a background, but a Story/Reels composition can receive a square
   visual instead of a full `1080x1920` background.
2. MCP text update or animation can create a second text layer instead of
   targeting the existing text.
3. MCP motion can fall back to a selected clip or a single visual clip when the
   intended remote target is unresolved.
4. A simple MCP background or text command can take 10-30 seconds to become
   visible.
5. `appApplied` or related proof can represent data/projection success rather
   than verified renderer truth.

These failures must be treated as one family:

```text
MCP intent bypasses canonical command truth
-> applies through type-specific legacy code
-> lacks strict active composition spec
-> lacks universal target identity
-> falls back to unsafe targets
-> waits for polling
-> reports proof too early
```

## 2. Evidence From Current Code

### 2.1 Background Can Still Bypass Background Intent

Current risk:

```text
kind == shape
-> applyShapeLayer
-> only later maybe recognized as background
```

If MCP sends a background as:

```json
{"kind":"shape","shape":"rect","width":1080,"height":1080}
```

inside a Story/Reels canvas, the app may treat it as a normal square shape,
because background classification depends on color and coverage heuristics.

Required correction:

```text
background intent must be classified before kind dispatch
```

The local active composition spec must be authoritative:

```text
Story/Reels selected locally => background bounds = active canvas bounds
```

MCP payload dimensions may be used only as authoring hints, not as final
background truth.

### 2.2 Text Update Is Improved But Not Universally Closed

Current improvement:

- text update can resolve an existing target and update it;
- duplicate short-circuit is more careful than before;
- some legacy animation payloads now run after text creation.

Remaining gap:

```text
multi-turn MCP intent without targetLayerId can still lose identity
```

Example:

```text
Command 1: insert text "test motion"
Command 2: add pop-up animation to the text
```

If command 2 arrives as a new remote layer, or as `insert_layer` with animation
but no stable target id, the runtime can still infer incorrectly.

Required correction:

```text
every MCP-created layer must enter a Universal Layer Identity Registry
every later update/motion/effect must resolve through that registry
ambiguous or unresolved update must fail closed
```

### 2.3 Motion Fallback Is Still Unsafe

Current risk:

```text
remote motion target not found
-> fallback to selected clip
-> fallback to single visual clip
```

This is acceptable for limited manual convenience only when the user is directly
editing a selected local object. It is unsafe for MCP targeted automation.

Required correction:

```text
MCP motion/effect/update with target intent:
  resolved target exists -> apply
  ambiguous target -> AMBIGUOUS_TARGET
  missing target -> TARGET_NOT_FOUND
  never silently target selected/single clip
```

### 2.4 Apply Latency Is Still Polling-Bound

Current risk:

```text
syncNow()
-> touch_editor_session
-> set_active_context
-> sync_editor_layers
-> get_active_context
-> get_pending_commands
-> get_layers
-> get_motion_channels
-> diagnostics
```

The bridge still has `_syncInFlight` and an 8s timeout. A slow network call can
delay the next command and make a simple visual change appear after 10-30s.

Required correction:

```text
command receive/apply path must be fast and separate from diagnostics
diagnostic snapshot may run later or in parallel
visual apply may not wait for project snapshot/evaluate_frame RPC chain
```

### 2.5 Proof Is Not Yet Renderer Proof

Current risk:

```text
dataApplied == true
-> frameEvaluated == true
-> visualProgramEmitted == true
-> rendererApplied maybe true
```

This can confirm a graph/data mutation, not actual pixel/renderer truth.

Required correction:

```text
appApplied=true only after:
  graph node exists
  timeline clip exists
  frame evaluator resolves bounds/properties
  preview renderer receives visual program
  renderer proof validates target bounds/kind
```

For a background:

```text
visualBounds == activeCanvasBounds
```

For a text update:

```text
createdTextCount unchanged
updatedElementId == targetElementId
```

For a motion/effect:

```text
targetElementId == resolved identity registry element
```

## 3. Non-Negotiable Architectural Rule

All old or partial paths must be deleted, disabled, or converted into adapters
into the new spine.

No source is allowed to apply directly:

```text
MCP direct setState
MCP metadata-only write
MCP placeholder timeline clip
MCP selected-clip fallback
Manual UI private graph mutation
Paste script private command parser
Template private element insertion
```

Allowed shape only:

```text
UI / MCP / Script / Templates / Tap List / Future Tools
-> Canonical SceneCommand
-> Composition Spec Gate
-> Intent Classifier
-> Universal Target Resolver
-> Unified Apply Engine
-> Creative Graph
-> Timeline Projection
-> Frame Evaluator
-> Preview Renderer
-> Export Renderer
-> Visual Proof/Ack
```

Any old path that cannot be deleted immediately must be wrapped by an adapter
that emits `Canonical SceneCommand` and has a removal ticket in this plan.

## 4. Root Fix Gates

### Gate 1: Active Composition Spec Gate

Goal: every command knows the active canvas.

The app must attach the active composition spec to every locally applied command:

```json
{
  "compositionId": "...",
  "canvas": {
    "width": 1080,
    "height": 1920,
    "aspect": "9:16",
    "preset": "Story",
    "fps": 30,
    "durationMs": 8000,
    "origin": "center"
  }
}
```

Rules:

- local active composition is authoritative;
- MCP-provided canvas dimensions are hints only;
- if MCP conflicts with local active composition, local composition wins;
- command proof must include the canvas spec used;
- any background/full-canvas command must use active canvas bounds.

Acceptance:

- create Story/Reels composition;
- MCP creates white background with `1080x1080` payload;
- result is full `1080x1920`;
- proof reports active canvas `1080x1920`;
- no square background appears.

### Gate 2: Canonical Intent Classifier

Goal: intent is classified before layer kind.

Classification priority:

1. explicit operation:
   - `set_background`
   - `set_background_color`
   - `insert_background`
   - `update_background`
   - `animate_layer`
   - `update_layer`
2. semantic role:
   - `background`
   - `title`
   - `primaryVideo`
3. target id / update id
4. layer kind:
   - text
   - shape
   - solid
   - media

This means:

```text
background shape rect
-> background command
not
-> generic shape command
```

Rules:

- background/full-canvas intent wins over `kind=shape`;
- update intent wins over insert wording;
- motion/effect intent wins over inserting a new visual node;
- unknown ambiguous intent must be rejected with a structured blocker.

Acceptance:

- `kind=shape + operation=background` routes to background apply;
- `kind=shape + name=Scene Background` routes to background apply;
- `kind=shape + fullCanvas=true` routes to background apply;
- normal rectangles still route to shape apply.

### Gate 3: Universal Layer Identity Registry

Goal: every visible thing has a stable identity across UI, MCP, script, and
template sources.

Each creative node must be registered:

```json
{
  "sourceIds": {
    "mcpRemoteLayerId": "...",
    "mcpAliases": ["..."],
    "localElementId": "...",
    "localLayerId": "...",
    "timelineClipId": "...",
    "scriptId": "...",
    "templateNodeId": "..."
  },
  "kind": "text|shape|background|image|video|audio|effect",
  "createdBy": "manual|mcp|script|template",
  "lastTouchedBy": "manual|mcp|script|template"
}
```

Rules:

- insert creates identity;
- update resolves identity;
- animation resolves identity;
- effect resolves identity;
- unresolved update never becomes insert;
- ambiguous target never chooses selected clip silently;
- selected clip fallback is allowed only for explicit manual UI commands.

Acceptance:

- MCP inserts text;
- MCP asks animation for same text without a new target but with recoverable
  conversational/last-created identity;
- same element receives motion;
- text count does not increase;
- if two candidate text nodes exist, command returns `AMBIGUOUS_TARGET`.

### Gate 4: Unified Apply Engine Adapter Cleanup

Goal: type-specific old paths become adapters only.

Required cleanup inventory:

```text
_applyRemoteSolidLayerIfNeeded
_applyRemoteShapeLayerIfNeeded
_applyRemoteTextLayerIfNeeded
_applyRemoteMotionChannel
manual insert shape/text paths
script scene program insertion paths
template insertion paths
```

Each path must be classified:

```text
delete
convert-to-adapter
keep-as-private-helper-under-unified-engine
```

Rules:

- no direct MCP path may mutate render/timeline state without the unified engine;
- no direct MCP path may create metadata-only visual state;
- no direct MCP path may add placeholder clips without graph nodes;
- all direct helpers must be private implementation details of the same apply
  engine, not alternative engines.

Acceptance:

- code search proves there is one entry point for MCP apply;
- code search proves background/text/shape/media commands all become canonical
  apply commands;
- tests fail if a new MCP-only direct apply path is added.

### Gate 5: Fast Apply Path

Goal: visible apply must be fast and diagnostics must not block it.

Split the bridge:

```text
Fast path:
  get pending command / realtime command event
  fetch affected layers/channels only
  apply locally
  proof/ack

Slow diagnostics path:
  get_canvas_metadata
  get_visual_layout_summary
  get_project_snapshot
  get_timeline_graph
  evaluate_frame
```

Rules:

- fast path does not wait for diagnostics;
- slow path cannot hold `_syncInFlight` for command apply;
- pending command fetch must be command-scoped;
- realtime is preferred;
- polling remains fallback only.

Budgets:

```text
MCP write -> local command received p95 <= 500ms with realtime
local command received -> canvas visible p95 <= 250ms
MCP write -> canvas visible p95 <= 1000ms with realtime
polling fallback visible p95 <= 8000ms
```

Acceptance:

- simple background command appears in under 1s on realtime path;
- if realtime unavailable, polling fallback is clearly marked;
- diagnostics can be slow without delaying visual apply.

### Gate 6: Renderer Proof/Ack

Goal: `appApplied=true` means rendered truth, not database truth.

Proof schema:

```json
{
  "dataApplied": true,
  "graphNodeExists": true,
  "timelineClipExists": true,
  "frameEvaluated": true,
  "visualProgramEmitted": true,
  "rendererApplied": true,
  "targetLayerId": "...",
  "targetElementId": "...",
  "operationApplied": "insert|update|motion|effect",
  "canvasBounds": {"x":0,"y":0,"width":1080,"height":1920},
  "visualBounds": {"x":0,"y":0,"width":1080,"height":1920},
  "createdLayerCount": 0,
  "updatedLayerCount": 1,
  "latencyMs": 143
}
```

Rules:

- background proof must compare visual bounds against canvas bounds;
- update proof must report unchanged element count;
- motion proof must report resolved target identity;
- proof cannot be inferred from revision increment;
- proof cannot be inferred from row existence.

Acceptance:

- square background cannot return `appApplied=true` for Story/Reels background;
- duplicate text cannot return update success;
- motion on wrong target cannot return success.

## 5. Required Cleanup List

The implementation must explicitly audit and remove or adapt these old behaviors:

1. Background classified after generic shape dispatch.
2. Solid/background metadata-only compatibility as the source of truth.
3. Shape full-canvas coverage heuristic as the only background detector.
4. MCP update falling back to insert when target cannot be resolved.
5. MCP motion falling back to selected clip or single visual clip.
6. Bridge diagnostics blocking command apply.
7. Proof evaluator treating `dataApplied` as renderer proof.
8. Any MCP-only path that bypasses canonical scene command.
9. Any manual UI path that bypasses the same graph/timeline/evaluator truth.
10. Any script/template path that creates elements outside the same identity
    registry.

Each cleanup item requires:

```text
old path name
decision: delete|adapter|keep-helper
replacement path
test proving old behavior cannot return
```

## 6. Execution Slices

### PUCTAS-FC-00: Failure Closure Pre-Build Report

Before code:

- cite the two current reviews;
- cite exact code paths;
- state selected slice;
- state old paths being removed/adapted;
- state tests and rollback.

No implementation may start without this report.

### PUCTAS-FC-01: Background Intent And Canvas Spec Closure

Scope:

- active composition spec gate;
- background intent before shape kind;
- full-canvas canonicalization;
- background proof bounds.

Do not touch:

- Live Scrub;
- Stage5 internals;
- unrelated text/motion behavior.

Tests:

- Story/Reels MCP background from `1080x1080` payload becomes `1080x1920`;
- square composition still supports square background;
- normal shape rect remains a shape;
- proof blocks square visual in Story/Reels.

Device E2E:

- create Story/Reels;
- MCP asks white background;
- result visible full canvas under performance budget.

### PUCTAS-FC-02: Universal Identity And Text/Motion Closure

Scope:

- universal identity registry for text first;
- cross-turn target memory;
- update vs insert fail-closed;
- motion/effect target resolution through same identity.

Tests:

- insert text once;
- update same text;
- animate same text;
- ambiguous two-text update blocks;
- unresolved target blocks;
- no selected/single clip fallback for MCP text motion.

Device E2E:

- MCP inserts `test motion`;
- MCP asks pop-up on same text;
- no duplicate text;
- animation target is same element.

### PUCTAS-FC-03: Fast Apply Bridge Closure

Scope:

- command apply separated from diagnostics;
- realtime or minimal pending-command path;
- diagnostics no longer block visual apply;
- latency measurement.

Tests:

- command apply path does not call heavy diagnostics before apply;
- `_syncInFlight` on diagnostics cannot block command apply;
- command-specific fetch gets only affected layers/channels.

Device E2E:

- MCP background visible under 1s on realtime path;
- if realtime unavailable, fallback status is explicit.

### PUCTAS-FC-04: Renderer Proof Closure

Scope:

- proof from graph + timeline + evaluator + renderer;
- bounds verification;
- target identity verification;
- no data-only success.

Tests:

- row exists but graph missing => not applied;
- graph exists but timeline missing => not applied;
- timeline exists but renderer bounds wrong => not applied;
- wrong target motion => not applied.

### PUCTAS-FC-05: Old Path Removal Gate

Scope:

- code search cleanup;
- tests that reject reintroduced bypasses;
- documentation update.

Required output:

```text
legacy path map
deleted paths
adapter paths
remaining private helpers
owner for any temporary compatibility path
removal deadline
```

## 7. E2E Acceptance Matrix

| Scenario | Expected Result |
|---|---|
| MCP background in Story/Reels | Full canvas background, not square |
| MCP background in Square | Square background matches canvas |
| MCP normal shape rect | Normal shape, not background |
| Manual shape then MCP edit | Same shape updates, no duplicate |
| MCP text then MCP update | Same text updates, no duplicate |
| MCP text then MCP pop-up | Same text animates |
| MCP update missing target | Fail closed, no insert |
| MCP motion missing target | Fail closed for targeted automation |
| Script background | Same graph/timeline/renderer result as MCP |
| Template background | Same graph/timeline/renderer result as MCP |
| UI background | Same graph/timeline/renderer result as MCP |

## 8. KPIs

```text
MCP_background_story_correct_bounds = 100%
MCP_text_update_duplicate_rate = 0%
MCP_motion_wrong_target_rate = 0%
appApplied_data_only_success_rate = 0%
MCP_to_visible_p95_realtime <= 1000ms
MCP_to_visible_p95_polling_fallback <= 8000ms
preview_export_parity_for_background >= 0.99
```

## 9. Stop List

Do not:

- patch background only in one local function while leaving shape dispatch first;
- add another MCP-only background fix;
- let payload width/height override active composition for background;
- keep selected clip fallback for MCP targeted updates;
- call `appApplied=true` from row/revision success;
- let diagnostics block visual apply;
- proceed to new creative effects until PUCTAS-FC-01 and PUCTAS-FC-02 are
  device-green.

## 10. Recommended Next Action

Start with:

```text
PUCTAS-FC-01: Background Intent And Canvas Spec Closure
```

Reason:

- it directly explains the visible square background failure;
- it validates active composition spec truth;
- it forces cleanup of the shape/background dispatch bypass;
- it is small enough to prove on device quickly;
- it creates the pattern for the later text/shape/video identity closure.

After `PUCTAS-FC-01` is device-green, proceed to:

```text
PUCTAS-FC-02: Universal Identity And Text/Motion Closure
```

Do not continue broad PUCTAS phases until these two closure gates are green.

## 11. Final Closure Definition

This failure family is closed only when:

```text
MCP background in Story/Reels
-> full canvas visible immediately
-> timeline clip linked to graph node
-> manual UI can select/edit it
-> MCP can update it without duplicate
-> proof includes correct visual bounds

MCP text then animation
-> same text element receives update/motion
-> no duplicate text
-> no selected-clip fallback
-> proof includes same targetElementId

MCP command latency
-> fast apply path visible under budget
-> diagnostics no longer block apply
```

Until all three are true on device, `PUCTAS` is not complete.
