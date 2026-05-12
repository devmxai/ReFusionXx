# Professional Composition Identity, Continuity, And Spatial Truth Plan

Short name: `PCICST`

Status: official corrective execution plan

Depends on:

- `professional_mcp_scene_truth_runtime_plan.md`
- `professional_agent_composition_truth_graph_plan.md`
- `professional_canvas_visual_motion_engine_plan.md`
- `professional_agent_pairing_and_identity.md`

## 1. Purpose

This plan closes the remaining structural gap between project creation,
agent-driven editing, timeline continuity, and spatially correct motion.

The previous plans correctly define the scene truth, composition graph, visual
motion engine, and agent pairing. The remaining failure is that these systems
are not yet enforced as one continuous workflow:

```text
Create or open composition
  -> bind real project/composition identity
  -> maintain one canonical editor snapshot
  -> expose a complete composition truth graph
  -> run every agent/manual edit as an authoring transaction
  -> solve spatial intent from real canvas and element geometry
  -> lower to renderable visual/motion programs
  -> verify renderer proof
  -> persist and acknowledge only after the open app applied it
```

Until this full chain is enforced, the app can still show these failures:

- a new composition reuses old layers,
- recent work leaks into a fresh project,
- agent edits conflict on stale revisions,
- later commands replace or reset earlier motion,
- spatial commands guess `x/y/scale`,
- elements move outside the intended canvas boundary,
- `appApplied=true` is returned before visual proof,
- background/foreground app lifecycle causes gradual reload or temporary state.

This plan is the integration closure for those failures.

## 2. Non-Negotiable Product Contract

### 2.1 Fresh Composition Contract

When the user taps `Create Composition`, the app must create a genuinely new
composition:

```text
new projectId
new rootCompositionId
new activeCompositionId
empty timeline
empty authored surfaces
empty motion channels
empty effects
new revision sequence starting from 0 or 1
new active context bound to this exact project/composition
```

No layer, clip, surface, effect, motion channel, applied command, pairing
context, cloud snapshot, or local editor cache from another composition may
enter the new composition.

The only valid way to reopen previous work is through `Recent Projects` or an
explicit open/import action.

### 2.2 Recent Projects Contract

Recent projects must be real project records, not a global scratch state.

Each recent entry must include:

```text
projectId
rootCompositionId
lastActiveCompositionId
displayName
thumbnail
updatedAt
durationMs
canvasPreset
localRevision
cloudRevision
dirty/syncStatus
```

Opening a recent project must load that project by ID. It must not reuse the
current in-memory editor state.

### 2.3 Persistence Contract

Once an edit is accepted and rendered, it becomes part of the canonical local
project snapshot.

When the app goes to background and returns:

- the current rendered project must stay available immediately,
- the user must not see layers loading one by one,
- the app must not temporarily revert to a default or stale cloud state,
- remote sync may merge later, but only after identity and revision checks.

The in-memory graph, local snapshot, cloud revision, and renderer state must
agree on the same active identity.

### 2.4 Sequential Agent Edit Contract

Agent commands must compose.

Example:

```text
1. Make the video a circular PIP and move it to top-right.
2. Add a pop-up entrance to that same video.
3. Add an exit-right animation at the end.
```

The expected result is one video surface with:

- the same target identity,
- one style/mask/effects stack,
- one motion timeline with entrance, main move, and exit phases,
- no duplicate video layers,
- no reset of the previous mask/move,
- no background modification unless explicitly requested.

### 2.5 Spatial Truth Contract

Every spatial edit must be solved from real composition geometry:

- canvas dimensions,
- coordinate system,
- safe zones,
- layer intrinsic size,
- rendered bounds,
- visible bounds after crop/mask,
- current transform,
- requested target anchor/zone,
- requested animation time range.

Natural-language spatial commands must use semantic solvers by default. Raw
pixel values remain allowed for professional precision, but agent-generated
commands must not guess pixels when an anchor, zone, or recipe can be used.

## 3. Root Causes To Eliminate

### 3.1 Fixed Identity Leakage

The application must eliminate production dependence on fixed IDs such as:

```text
motion-project
scene-main
default
active
comp_1
MCP Project
```

These names may exist only in test fixtures or migration compatibility paths.

### 3.2 Context Fallback Leakage

The app must not drop project/composition IDs because they are not UUID-like and
then fall back to the last cloud context.

Any cloud context operation must be explicit:

```text
activeProjectId == snapshot.projectId
activeCompositionId == snapshot.compositionId
```

If identity does not match, the snapshot is ignored and a diagnostic is emitted.

### 3.3 Fatal Revision Conflicts

`expectedRevision` is an optimistic guard, not the only editing model.

When a conflict occurs, the transaction manager must:

1. fetch the latest composition truth graph,
2. check whether the edit can be safely rebased,
3. merge non-overlapping edits,
4. reject only real conflicts with a structured explanation.

### 3.4 Motion Replacement Instead Of Motion Merge

Adding a new motion requirement must not overwrite unrelated motion phases.

The motion system must support named phases:

```text
intro
hold
main
move
style
exit
```

Each phase compiles into renderable motion channels. Later edits may patch one
phase without replacing the entire animation.

### 3.5 Geometry Guessing

Any spatial edit that depends on canvas boundaries, corners, offscreen exits,
or PIP placement must use the shared spatial solver.

This includes:

- move to top-right,
- exit right,
- center to corner,
- circular PIP,
- keep inside canvas,
- align to title safe,
- fit/fill a zone,
- slide out of canvas.

## 4. Canonical Data Contracts

### 4.1 ProjectIdentity

```text
ProjectIdentity
  projectId: uuid
  rootCompositionId: uuid
  activeCompositionId: uuid
  ownerId: uuid
  localRevision: int
  cloudRevision: int?
  source: local | cloud | imported
  createdAt: timestamp
  updatedAt: timestamp
```

### 4.2 CompositionIdentity

```text
CompositionIdentity
  compositionId: uuid
  projectId: uuid
  name: string
  preset: story | landscape | square | custom
  width: int
  height: int
  fps: int
  durationMs: int
  origin: centerOrigin
  revision: int
```

### 4.3 EditorSnapshot

```text
EditorSnapshot
  identity: ProjectIdentity
  composition: CompositionIdentity
  timeline: tracks + clips
  surfaces: authored surfaces
  motionChannels: canonical motion channels
  effects: canonical effects
  selection: selected surface/clip IDs
  playheadMs: int
  appliedCommandIds: list
  rendererReceipt: last proof receipt
```

### 4.4 AuthoredSurface

Every visible node must become an authored surface:

```text
AuthoredSurface
  surfaceId: uuid
  layerId: uuid
  clipId: uuid?
  kind: background | video | image | text | shape | audio | adjustment
  intrinsicSize: width/height?
  timelineRange: startMs/durationMs
  sourceRange: startMs/durationMs?
  transform: position/scale/rotation/anchor
  style: opacity/fill/stroke/shadow/glow/blend
  crop: cropRect/aspect
  mask: none/circle/rect/roundedRect/custom
  effects: ordered effect stack
  motionChannels: property channels
  capabilities: renderable operations
```

No video, image, text, or shape may bypass this surface contract through a
special overlay-only path.

### 4.5 AuthoringTransaction

```text
AuthoringTransaction
  commandId: uuid
  idempotencyKey: string
  intentId: string?
  projectId: uuid
  compositionId: uuid
  baseRevision: int
  observedRevision: int
  targetRefs: semantic or exact refs
  operations: list of authoring operations
  mergePolicy: appendNonOverlapping | updateExistingAtTime | replaceExplicit
  waitForApply: bool
```

### 4.6 MotionSegment

```text
MotionSegment
  segmentId: uuid
  surfaceId: uuid
  phase: intro | hold | main | move | style | exit
  timeRange: startMs/durationMs
  recipeId: string?
  generatedChannels: list of property channels
  mergePolicy: append | patch | replaceExplicit
```

### 4.7 SpatialIntent

```text
SpatialIntent
  targetSurfaceId: uuid
  operation:
    position.at_anchor |
    move.to_anchor |
    fit_in_zone |
    scale_to |
    keep_in_canvas |
    exit.direction |
    pip.circular_to_corner
  coordinateSpace: centerOriginCanonical
  anchorOrZone: string
  paddingPx: number
  safeArea: none | titleSafe | actionSafe
  animate: optional timing/easing
```

## 5. Required Execution Phases

### PCICST-00: Failure Lockdown Fixtures

Create fixtures before implementation changes.

Required fixtures:

1. Create Composition A, add background/text/video.
2. Create Composition B, verify it is empty.
3. Reopen A from Recent, verify A content only.
4. Background app and resume, verify no gradual reload or stale flash.
5. Add circular PIP move, then add popup entrance, then add exit-right.
6. Send an edit with stale revision and verify safe rebase or structured conflict.
7. Move text exit-right and verify it exits through the right canvas boundary.

Acceptance:

- every known failure is reproducible before the fix,
- every fixture has expected project/composition IDs,
- screenshots or frame proofs identify actual bounds when relevant.

### PCICST-01: Composition Identity State Machine

Introduce a strict editor state machine:

```text
NoActiveProject
CreatingProject
ProjectOpen
ProjectSyncing
ProjectClosing
ProjectError
```

Startup must enter `NoActiveProject` unless an explicit restore policy opens
the last project. Creating a project is an explicit transition, not an implicit
side effect of `initState`.

Acceptance:

- no production project is created with fixed IDs,
- `Create Composition` generates new UUIDs,
- the active cloud context is cleared or rebound to the new identity,
- selection, remote applied IDs, preview state, and transaction caches reset.

### PCICST-02: Project Repository And Recent Index

Create a project repository boundary:

```text
ProjectRepository
  createProject(template)
  openProject(projectId)
  saveSnapshot(EditorSnapshot)
  listRecentProjects()
  markRecent(projectId)
  closeProject(projectId)
  syncProject(projectId)
```

Implement local-first persistence before relying on cloud sync.

Acceptance:

- a fresh project snapshot is saved immediately after creation,
- Recent Projects reads from real stored entries,
- opening a recent project does not reuse active in-memory state,
- cloud sync cannot override a different active project.

### PCICST-03: Fresh Create Transaction

Make `Create Composition` one atomic transaction:

```text
generate identity
create empty composition graph
create empty timeline
persist local snapshot
bind active context
subscribe to project-specific realtime
render empty canvas
```

Acceptance:

- Composition B has no layers from Composition A,
- remote snapshots from A are ignored while B is active,
- agent pairing code generated in B binds only to B.

### PCICST-04: Resume And Background Persistence

The open editor must preserve the canonical in-memory graph and the local
snapshot across background/foreground.

Acceptance:

- returning from background shows the same frame immediately,
- no default canvas flash,
- no step-by-step remote replay,
- remote sync merges only after identity and revision validation.

### PCICST-05: Active Context Binding

Every app session, pairing code, agent session, and MCP mutation must bind to:

```text
userId
deviceId
appSessionId
projectId
compositionId
revision
```

Acceptance:

- `get_project_state` always reports the active project/composition IDs,
- a command for Project A cannot mutate Project B,
- wrong-context updates return `WRONG_ACTIVE_CONTEXT` and do not render.

### PCICST-06: Authoring Transaction Manager

Route all mutating commands through one transaction manager:

```text
read snapshot
resolve target
build patch
dry-run
rebase or merge
commit atomically
wait_for_apply
return proof
```

Acceptance:

- every mutation returns `commandId`, `revisionBefore`, `revisionAfter`,
  `targetIds`, and `proofStatus`,
- duplicate idempotency keys return the previous result,
- `REVISION_CONFLICT` includes `actualRevision` and `rebaseHint`,
- safe non-overlapping changes rebase automatically.

### PCICST-07: Target Resolution And Edit Continuity

Add stable target resolution:

```text
exact layerId/surfaceId
selectedSurface
lastCreatedByAgent
semanticId
layerName with disambiguation
clipId
```

Acceptance:

- `add popup to that video` targets the existing selected or referenced video,
- no duplicate layer is created unless the command explicitly asks for one,
- agent commands can continue from returned `targetIds`.

### PCICST-08: Motion Merge Semantics

Add a motion-aware merge layer.

Required rules:

- `appendMotion` adds a segment to an existing surface.
- `replaceMotion` requires explicit user/tool intent.
- `intro` edits do not overwrite `move` or `exit`.
- `exit` edits do not overwrite `intro`.
- keyframes merge by property and time range.
- true overlap on the same property/time returns a structured conflict.

Acceptance:

- `popup intro` followed by `move topRight` followed by `exit right` renders
  as one continuous motion timeline on the same surface,
- the background color and layer order remain unchanged unless requested.

### PCICST-09: Canvas Geometry Truth

Expose one canonical geometry model for app, MCP, UI tools, preview, and export.

Required projections:

```text
get_canvas_metadata
get_element_geometry(timeMs)
get_visual_layout_summary
evaluate_frame(timeMs)
```

Acceptance:

- Story 1080x1920 reports exact bounds, center-origin ranges, safe zones,
  anchors, and duration,
- each element reports intrinsic bounds, world bounds, visible bounds,
  safe-area compliance, and offscreen amount,
- missing intrinsic media dimensions produce `MISSING_INTRINSIC_SIZE` and do
  not allow guessed movement.

### PCICST-10: Semantic Spatial Solver

Implement semantic spatial operations as solver-backed commands:

```text
surface.position.at_anchor
surface.move.to_anchor
surface.fit_in_zone
surface.scale_to
surface.center_in
surface.keep_in_canvas
surface.exit.direction
recipe.circular_pip_to_corner
```

Required solver examples:

```text
topRight PIP:
  centerX = canvasWidth - margin - diameter / 2
  centerY = margin + diameter / 2
  canonicalX = centerX - canvasWidth / 2
  canonicalY = centerY - canvasHeight / 2

exitRight:
  finalCenterX = canvasRight + visibleWidth / 2 + overscan
  finalCenterY = current or solved lane center
```

Acceptance:

- the agent never has to guess coordinates for PIP/corner/exit commands,
- `exit right` exits through the right edge, not top, bottom, or background
  padding,
- `move to top-right` lands inside action-safe bounds unless the user asks
  otherwise.

### PCICST-11: Visual Program Lowering And Renderer Parity

Lower all accepted operations to renderable visual programs.

The same authored surface must drive:

- Flutter preview,
- transform handles,
- timeline thumbnails,
- Stage5 preview/export where supported,
- visual proof receipts.

Acceptance:

- mask, border, shadow, glow, transform, and motion use the same surface model,
- no renderer reads only base `x/y/scale` while ignoring motion/style channels,
- unsupported renderer capability returns `RENDERER_CAPABILITY_MISSING`, not
  silent success.

### PCICST-12: Proof Receipt And `wait_for_apply`

Replace loose success with a proof receipt:

```text
dataCommitted
localSnapshotApplied
truthGraphEvaluated
visualProgramLowered
rendererApplied
visualBoundsVerified
persistedSnapshot
```

`appApplied=true` may be returned only when the required proof level passes.

Acceptance:

- metadata-only changes are not reported as rendered,
- `wait_for_apply(commandId)` checks the command ID, not only revision number,
- the agent cannot claim success before the open app proves the change.

### PCICST-13: Agent Contract And Skill Updates

Update MCP tool descriptions and agent authoring skills.

Agents must:

1. read project/composition truth before complex writes,
2. use semantic spatial operations for layout/motion intent,
3. use returned `targetIds` for follow-up edits,
4. pass idempotency keys for repeated operations,
5. call `wait_for_apply`,
6. report structured conflicts instead of claiming success.

Acceptance:

- natural language "move it to the upper-right corner" compiles through
  `surface.move.to_anchor`, not raw guessed pixels,
- "add popup to the same video" uses the current target identity,
- "make it exit right" patches the exit phase.

### PCICST-14: Manual UI Uses The Same Engine

The fixes must not be MCP-only.

Future UI controls for alignment, PIP, mask, border, glow, and motion must call
the same project repository, transaction manager, geometry solver, and visual
program lowering.

Acceptance:

- manual transform and agent transform produce the same geometry result,
- manual PIP and agent PIP share the same recipe,
- manual edits persist through background/resume and recent reopen.

### PCICST-15: Decommission Unsafe Paths

After the replacement paths pass acceptance, remove or quarantine:

- fixed production IDs,
- global scratch project state,
- latest-solid-wins background inference,
- scene-program fallback for existing-layer animation,
- raw coordinate guessing in agent spatial commands,
- metadata-only success,
- app/session context fallback to previous cloud project,
- renderer paths that bypass authored surfaces.

Acceptance:

- stop-list paths fail tests if reintroduced,
- diagnostics point to the replacement operation.

## 6. End-To-End Acceptance Suite

### 6.1 Fresh Composition

```text
Create A
Add red background and text
Create B
Expected: B is empty and clean
Open Recent A
Expected: A contains red background and text
Open Recent B
Expected: B is still empty
```

### 6.2 Project Isolation With MCP

```text
Open A and pair agent
Create B
Agent command still targeting A arrives
Expected: ignored with WRONG_ACTIVE_CONTEXT while B is active
```

### 6.3 Background/Foreground Persistence

```text
Add video, mask, border, glow, motion
Background app
Resume app
Expected: same frame is visible immediately
Expected: no gradual reload and no stale default state
```

### 6.4 Sequential Motion Continuity

```text
Command 1: make video circular PIP and move to top-right
Command 2: add popup entrance to the same video
Command 3: add exit-right at the end
Expected: one video surface, one style stack, one merged motion timeline
```

### 6.5 Revision Rebase

```text
Command has expectedRevision=27
Server actualRevision=28
Change targets same surface but non-overlapping intro phase
Expected: rebase and commit
```

If the same property/time is edited differently:

```text
Expected: structured conflict with target/property/time details
```

### 6.6 Spatial Solver Accuracy

For Story 1080x1920 and circular PIP diameter 360, margin 72:

```text
topRight center = (828, 252)
canonical = (288, -708)
bounds = left 648, top 72, right 1008, bottom 432
```

For exit-right:

```text
final centerX = 540 + visibleWidth / 2 + overscan
```

Expected:

- the element exits through the right canvas edge,
- visual proof confirms offscreen direction is right,
- no vertical drift unless explicitly requested.

### 6.7 Renderer Proof

For every accepted visual command:

```text
proof.dataCommitted = true
proof.localSnapshotApplied = true
proof.truthGraphEvaluated = true
proof.visualProgramLowered = true
proof.rendererApplied = true
proof.visualBoundsVerified = true
```

If a renderer cannot draw the requested effect:

```text
rendererApplied = false
reason = RENDERER_CAPABILITY_MISSING
```

The command must not be reported as visually successful.

## 7. Implementation Order

Recommended strict order:

1. `PCICST-00` failure fixtures.
2. `PCICST-01` identity state machine.
3. `PCICST-02` repository and recent index.
4. `PCICST-03` fresh create transaction.
5. `PCICST-04` resume persistence.
6. `PCICST-05` active context binding.
7. `PCICST-06` authoring transaction manager.
8. `PCICST-07` target resolution.
9. `PCICST-08` motion merge.
10. `PCICST-09` geometry truth.
11. `PCICST-10` spatial solver.
12. `PCICST-11` renderer parity.
13. `PCICST-12` proof receipt.
14. `PCICST-13` agent contract.
15. `PCICST-14` manual UI reuse.
16. `PCICST-15` unsafe path removal.

Do not start with visual polish. Fix identity and transaction continuity first,
then geometry truth, then renderer proof.

## 8. Stop List

Do not:

- create a new composition by mutating the old active project,
- reuse fixed IDs in production,
- apply a cloud snapshot without identity match,
- treat `REVISION_CONFLICT` as an unrecoverable default for all edits,
- add a second layer when the command clearly targets an existing layer,
- replace the whole scene to add animation to an existing layer,
- use raw guessed `x/y/scale` for semantic spatial requests,
- report `appApplied=true` before renderer proof,
- let background/foreground replay remote layers over the current local graph,
- implement MCP-only fixes that manual UI cannot reuse.

## 9. Review Inputs Incorporated

This plan incorporates three independent review tracks:

1. Project/composition isolation review:
   - fixed IDs and missing recent-project identity cause old edits to leak into
     new compositions.
   - solution: identity state machine, repository, recent index, context guard.

2. Transaction/revision continuity review:
   - sequential agent edits fail because each command is treated as an isolated
     revision mutation.
   - solution: authoring transactions, target resolution, idempotency,
     rebase/merge, wait-for-apply by command ID.

3. Spatial truth review:
   - motion fails spatially because the agent lacks canvas and element geometry,
     and renderer paths do not share one authored-surface contract.
   - solution: geometry truth, semantic solvers, visual program lowering, and
     renderer proof receipts.

## 10. Definition Of Done

This plan is complete only when:

- `Create Composition` always produces a clean project/composition identity,
- Recent Projects can reopen previous work without leakage,
- background/resume keeps the current visual state stable,
- agent edits can build on previous edits without reset,
- revision conflicts are rebased or reported precisely,
- spatial commands use real canvas and element geometry,
- text/video/image/shape all share authored surface behavior,
- mask/border/glow/transform/motion render on the open device,
- `appApplied=true` means the open app actually rendered and verified the
  requested change.

