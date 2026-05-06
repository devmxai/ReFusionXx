# Professional Motion Builder Plan

Status: official implementation plan  
Project: `ReFusionXx`  
Primary target: `TRUEFRAME TRANSFORM VELOCITY MOTION BLUR`  
Audience: Codex 5.3 writer agent and future ReFusion agents  
Scope: realtime preview, live scrub, playback, future export alignment

## 0. Executive Decision

ReFusionXx must stop trying to make realtime Motion Blur work through the old
temporal multi-sample / bitmap proof / professional overlay path.

The new realtime Motion Blur system is:

```text
TrueFrame motion truth
-> MotionBlurDirective
-> Stage5 visible surface
-> GPU shader pass
-> final visible pixels
```

The old path is not allowed to remain as a hidden fallback, secondary renderer,
or alternate source of truth.

The new effect is:

```text
Authored Transform Velocity Motion Blur
```

It supports:

- Position blur: directional linear blur.
- Rotation blur: angular/radial blur around the anchor.
- Scale blur: zoom/radial blur from the anchor or center.
- Combined blur: position + rotation + scale velocity in one velocity field.

It does not implement optical flow, pixel-motion analysis, or source-footage
motion estimation in this phase.

## 1. Non-Negotiable Architecture Rule

TrueFrame owns the meaning.

Stage5 executes the realtime adapter.

This means:

```text
MasterMotionBlurPolicy / TrueFrame evaluation = semantic truth
MotionBlurDirective = renderer-ready realtime instruction
Stage5 shader pass = realtime execution adapter
```

Stage5 must not become a second animation engine.

The professional transition compositor must not own realtime Motion Blur.

Export may later use Media3 / OpenGL / temporal multi-sample quality modes, but
it must consume the same semantic truth and not reinterpret keyframes or time.

## 2. Old Path Removal Requirement

Before the new system is accepted, the old realtime Motion Blur path must be
removed from production reachability.

Delete, disconnect, or quarantine with impossible production routing:

- Professional overlay Motion Blur ownership.
- `ProfessionalVideoTransitionSurfaceOverlay` as realtime Motion Blur owner.
- Professional surface drawn above Stage5 for Motion Blur.
- `MediaMetadataRetriever` realtime Motion Blur usage.
- `getFrameAtTime` realtime Motion Blur usage.
- `Bitmap` / `Canvas` / `getPixels` / `createBitmap` realtime Motion Blur usage.
- `debugBitmapProof` / `bitmapProof` as user-visible Motion Blur path.
- `forcedVisualTestPattern` and `forcedSyntheticMotionBlur` as success paths.
- realtime `nativeWriterSamplePayload`.
- realtime `temporalMotionBlurSamplePlans`.
- realtime `sampleContributions`.
- realtime `motionBlurSamples` lists.

Allowed exception:

Temporal multi-sample data may remain only for future export/offline quality
mode, behind explicit `renderingMode = temporalMultiSample`, and must not be
connected to preview, live scrub, or playback.

Acceptance for cleanup:

```text
preview/liveScrub/playback Motion Blur has no MediaMetadataRetriever path
preview/liveScrub/playback Motion Blur has no Bitmap/Canvas path
preview/liveScrub/playback Motion Blur has no professional overlay path
Stage5 remains the only visible realtime surface
Rotation still works
Gaussian Blur still works
No black frame
No duplicate layer
No overlay rectangle
```

## 3. Domain Contract

Keep `MasterMotionBlurPolicy` as the semantic source.

Do not delete or rename:

- `amount`
- `shutterAngleDegrees`
- `shutterPhaseDegrees`
- `samples`
- `affectPosition`
- `affectScale`
- `affectRotation`
- `adaptiveSampleLimit`
- `maxTrailPx`

Add:

```text
renderingMode
```

Allowed values:

```text
transformVelocity
temporalMultiSample
```

Default:

```text
transformVelocity
```

Meaning:

- `transformVelocity`: realtime preview, live scrub, playback.
- `temporalMultiSample`: future export/offline high-quality rendering.

## 4. MotionBlurDirective

Create a renderer-ready directive model.

Suggested name:

```text
MotionBlurDirective
```

Required fields:

```text
enabled
amount
kernelLengthPx
directionX
directionY
radialOmega
scaleVelocityX
scaleVelocityY
anchorXNormalized
anchorYNormalized
shutterAngleDegrees
shutterPhase
sampleCount
maxTrailPx
mode
fallbackReason
```

Rules:

- It must not contain decoded frames.
- It must not contain sample bitmap requests.
- It must not contain `sampleContributions`.
- It must not contain temporal decoder plans.
- It must be small enough to pass every frame without JNI pressure.

## 5. Velocity Compiler

Create:

```text
lib/features/editor/domain/services/motion_blur_velocity_compiler.dart
```

The compiler consumes:

- `MasterMotionBlurPolicy`
- evaluated transform at time `t`
- evaluated transform at `t - shutterDuration`
- canvas width and height
- FPS
- anchor / center
- quality mode

The compiler outputs:

```text
MotionBlurDirective
```

Timing must be evaluated in Dart using the existing motion truth:

```text
UniversalMotionGraph
-> MasterFrameEvaluation
-> MasterVisualProgram
-> TrueFrame/Core evaluator
```

Kotlin must not infer keyframe timing.

Required formulas:

```text
shutterDuration = (shutterAngleDegrees / 360) / fps
positionDeltaPx = position(t) - position(t - shutterDuration)
kernelLengthPx = length(positionDeltaPx) * amount
kernelDirection = normalize(positionDeltaPx)
radialOmega = rotationDeltaRadians * amount
scaleVelocity = scaleDelta * amount
kernelLengthPx = min(kernelLengthPx, maxTrailPx)
```

Disable the directive when:

```text
amount <= 0.001
or kernelLengthPx <= 0.5 and radial/scale velocity are negligible
```

The compiler must respect:

- `affectPosition`
- `affectRotation`
- `affectScale`
- `shutterPhaseDegrees`
- `maxTrailPx`
- quality sample count

## 6. Render Graph Dispatch

For realtime, Motion Blur must no longer be a temporal sample plan.

It becomes a dispatch directive:

```text
effectId = transformVelocityMotionBlur
renderingMode = transformVelocity
velocitySource = transformDelta
semanticOwner = TrueFrameCore
executionOwner = Stage5RealtimeShaderAdapter
directive = MotionBlurDirective
```

Do not emit for preview/liveScrub/playback:

- `sampleContributions`
- `sampleOffsetsMs`
- `nativeWriterSamplePayload`
- temporal decoder requests

For future export only:

```text
renderingMode = temporalMultiSample
```

may emit temporal data, but it must be clearly separated from realtime.

## 7. Stage5 Runtime Bridge

Replace realtime sample-list delivery with one directive.

Create or update:

```text
Stage5VisualRuntimeMotionBlurDirective
```

Bridge payload fields:

```text
enabled
amount
kernelLengthPx
directionX
directionY
radialOmega
scaleVelocityX
scaleVelocityY
anchorXNormalized
anchorYNormalized
sampleCount
shutterPhase
maxTrailPx
fallbackReason
```

Update adapters:

- `master_live_scrub_program_adapter.dart`
- `Stage5NativeScrubEngine.kt`
- `Stage5PreviewPlatformView.kt`
- `Stage5ScrubOverlayTextureView.kt`

Rules:

- Pass one directive per visible runtime surface state.
- Do not pass `motionBlurSamples`.
- Do not pass temporal sample lists.
- Do not pass bitmap frame data.
- Keep Rotation and Gaussian Blur payload behavior unchanged.

## 8. Stage5 GPU Shader Pass

Create:

```text
Stage5MotionBlurShaderPass.kt
```

Primary realtime implementation:

```text
API 33+
RuntimeShader / AGSL
RenderEffect.createRuntimeShaderEffect
```

The shader effect must be applied in the same runtime effects path where
Gaussian Blur is currently applied.

Fallback:

```text
API 31-32
Motion Blur disabled with explicit fallbackReason=runtime_shader_api_not_available
```

Do not implement fallback using:

- Bitmap
- Canvas
- MediaMetadataRetriever
- overlay surface
- duplicate PlatformView

Future fallback may be a separate GL ES checkpoint, but it must not be mixed
with this MVP.

## 9. Shader Behavior

For each pixel:

1. Compute linear velocity:

```text
linearVelocity = direction * kernelLengthPx
```

2. Compute rotation velocity:

```text
radialVelocity = radialOmega * perpendicular(pixel - anchor)
```

3. Compute scale velocity:

```text
zoomVelocity = scaleVelocity * (pixel - anchor)
```

4. Combine:

```text
velocity = linearVelocity + radialVelocity + zoomVelocity
```

5. Sample along velocity:

```text
sampleCount = 4 / 6 / 8
weights = normalized
shutterPhase controls trail / center / lead
```

6. Output one final RGBA pixel.

Quality targets:

```text
liveScrub = 4 samples
playback = 6 samples
high preview = 8 samples
future export = separate Media3 / GL path
```

## 10. Visual Targets

Position:

- Linear blur.
- Direction follows movement.
- Length grows with speed and amount.

Rotation:

- Radial / angular blur.
- Centered around anchor.
- Length grows with rotation velocity.

Scale:

- Zoom / radial blur.
- Expands from or contracts to anchor / center.
- Length grows with scale velocity.

Combined:

- Position + rotation + scale are combined in one velocity field.
- Excessive velocity is clamped.
- No full-screen Gaussian wash.
- No harsh pixel tearing.
- No transparent duplicate layer.

## 11. Gating

Apply the shader only if:

```text
directive.enabled == true
directive.amount > 0.001
kernelLengthPx > 0.5 or radial/scale velocity is meaningful
surface is visible
API supports the selected shader path
```

Otherwise:

```text
Motion Blur RenderEffect = null
```

No silent fallback is allowed.

Every inactive state must have an explicit reason:

```text
motion_blur_disabled
motion_blur_amount_zero
motion_blur_velocity_zero
runtime_shader_api_not_available
surface_not_visible
```

## 12. Required Logs

Emit:

```text
TF_VELOCITY_MB_PROOF
```

Required fields:

```text
enabled
amount
kernelLengthPx
directionX
directionY
radialOmega
scaleVelocityX
scaleVelocityY
sampleCount
rendererPath=stage5VelocityShader
sourceProviderMode=currentVisibleSurface
stage5Visible=true
professionalSurfaceVisible=false
overlayConflict=false
bitmapAllocationCount=0
mediaMetadataRetrieverUsed=false
renderEffectApplied
fallbackReason
```

Success example:

```text
TF_VELOCITY_MB_PROOF enabled=true amount=1.0 kernelLengthPx=32.4 rendererPath=stage5VelocityShader sourceProviderMode=currentVisibleSurface overlayConflict=false bitmapAllocationCount=0 mediaMetadataRetrieverUsed=false renderEffectApplied=true
```

## 13. Tests

Required Dart tests:

- position velocity directive.
- rotation velocity directive.
- scale velocity directive.
- combined velocity directive.
- `amount = 0` disables.
- no motion disables.
- shutter angle affects kernel length.
- shutter phase is preserved.
- `maxTrailPx` clamps extreme motion.
- affect toggles are respected.

Required bridge tests:

- Stage5 runtime payload contains one `MotionBlurDirective`.
- realtime payload does not contain `motionBlurSamples`.
- realtime payload does not contain temporal sample plans.
- render graph emits `transformVelocityMotionBlur`.
- preview/liveScrub/playback do not emit realtime temporal decoder requests.

Required native guard tests:

- realtime Motion Blur does not use `MediaMetadataRetriever`.
- realtime Motion Blur does not use `getFrameAtTime`.
- realtime Motion Blur does not use `Bitmap`.
- realtime Motion Blur does not use `Canvas`.
- professional compositor cannot own realtime Motion Blur.
- `ProfessionalVideoTransitionSurfaceOverlay` cannot be realtime Motion Blur owner.
- overlay conflict is impossible.

Required device checks:

- position keyframes show directional blur.
- rotation keyframes show radial blur.
- scale keyframes show zoom blur.
- combined transform shows mixed blur.
- `amount = 0` removes blur immediately.
- Rotation still works.
- Gaussian Blur still works.
- Live Scrub remains smooth.
- Playback remains smooth.
- no black frame.
- no duplicate layer.
- no overlay rectangle.

## 14. Stop List

Do not:

- restore the old professional overlay path.
- implement Motion Blur through `ProfessionalVideoTransitionCompositorManager`
  for realtime preview/liveScrub/playback.
- use `MediaMetadataRetriever`.
- use `Bitmap`.
- use `Canvas`.
- use `getFrameAtTime`.
- use debug markers as success.
- use synthetic blur as success.
- build a second visible surface.
- hide Stage5 because of Motion Blur.
- make Stage5 a semantic engine.
- break `MasterMotionBlurPolicy`.
- mix preview shader with future export pipeline.

## 15. Implementation Order

### Phase 1: Cleanup

- Remove old realtime Motion Blur routing.
- Ensure all old proof paths are unreachable for preview/liveScrub/playback.
- Add guard tests for forbidden paths.
- Verify Rotation and Gaussian Blur still work.

### Phase 2: Directive Model And Compiler

- Add `renderingMode`.
- Add `MotionBlurDirective`.
- Add `motion_blur_velocity_compiler.dart`.
- Add focused unit tests.

### Phase 3: Graph And Bridge

- Emit `transformVelocityMotionBlur` directive from the graph.
- Bridge the directive to Stage5 runtime state.
- Remove realtime sample-list bridge.

### Phase 4: Directional Shader MVP

- Implement position/directional blur first.
- Apply through Stage5 runtime effects.
- Verify preview/liveScrub/playback.

### Phase 5: Rotation And Scale Extension

- Add radial velocity for rotation.
- Add zoom velocity for scale.
- Verify image, video, shape, text/sticker targets where available.

### Phase 6: Polish

- Add sample-quality tiers.
- Add max-trail clamps.
- Tune shutter phase.
- Add device logs and profiling evidence.

### Phase 7: Final Legacy Cleanup

- Remove any remaining old realtime Motion Blur code.
- Keep future export temporal mode only if clearly isolated.
- Run full focused validation.

## 16. Build And Verification

Run:

```bash
flutter test
flutter build apk --debug
flutter install --debug -d <connected-device>
```

Then validate manually on device:

- preview
- live scrub
- playback
- amount changes
- keyframe changes
- position blur
- rotation blur
- scale blur
- combined blur

## 17. Checkpoint Policy

After each focused build step:

```text
stage only focused files
commit: checkpoint: <specific step>
push the branch to GitHub
install the APK on the connected Android device when available
report commit hash and rollback command
```

Final checkpoint:

```text
checkpoint: implement trueframe transform velocity motion blur
```

Rollback:

```bash
git revert <commit-hash>
```

## 18. Final Acceptance Criteria

The implementation is accepted only when:

1. Motion Blur is visible in preview.
2. Motion Blur is visible in live scrub.
3. Motion Blur is visible in playback.
4. Position blur is directional.
5. Rotation blur is radial around anchor.
6. Scale blur is zoom/radial.
7. Combined blur works without tearing.
8. `amount = 0` has no visual effect and no shader cost.
9. Rotation still works.
10. Gaussian Blur still works.
11. No overlay surface appears.
12. No professional compositor owns realtime Motion Blur.
13. No `Bitmap` / `Canvas` / `MediaMetadataRetriever` path remains in realtime.
14. No debug synthetic output remains.
15. No old temporal realtime sample path remains.
16. Stage5 remains the single visible realtime surface.
17. TrueFrame remains the semantic owner.
18. Stage5 is only the realtime shader adapter.
19. Tests pass.
20. Debug APK builds.
21. Device install succeeds.
22. Manual device verification confirms smooth playback and live scrub.

Critical final rule:

If the Stage5 GPU shader path cannot be completed safely, do not restore the old
path. Leave Motion Blur disabled with an explicit fallback reason. Never bring
back overlay, bitmap proof, or `MediaMetadataRetriever` realtime Motion Blur.

