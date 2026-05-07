# ReFusion Output Contract

## Purpose

This contract defines the output any agent must produce for ReFusion-native
scene authoring.

## Non-Negotiable

Final scene output is JSON only. The scene must be importable, editable, and
represented as explicit layers, elements, channels, keyframes, interpolation,
and effects.

Forbidden as final output:

- HTML
- CSS
- JavaScript
- JSX
- GSAP
- Lottie JSON as the scene source of truth
- shader source
- remote imports
- screenshots or rendered video as the only artifact

## Required Wrapper

Prefer a Director-first wrapper:

```json
{
  "directorPlan": {
    "schemaVersion": "refusion.motion-director/v1",
    "name": "Readable Plan Name",
    "durationMs": 3200,
    "frameRate": 30,
    "canvasWidth": 1080,
    "canvasHeight": 1920,
    "beats": [],
    "components": [],
    "primitives": []
  },
  "sceneProgram": {
    "schemaVersion": "refusion.scene-program/v1",
    "name": "Readable Scene Name",
    "durationMs": 3200,
    "frameRate": 30,
    "layers": []
  }
}
```

## Scene Mental Model

Use a center-origin canvas:

```text
portrait default: 1080 x 1920
x=0,y=0       center
x=-540,y=-960 top-left
x=540,y=960   bottom-right
```

Allowed layer/element families:

- shape
- text
- image
- video
- icon when backed by ReFusion core icon names

Use shapes for modern UI forms:

- rectangle
- roundedRectangle
- circle
- line

## Editability Requirements

Every meaningful object must have:

- stable `id`
- semantic role or readable label
- explicit properties
- channels for animated properties
- keyframes inside layer lifetime
- interpolation using supported timing contracts

Static property values do not count as animation. If something fades, moves,
rotates, scales, blurs, or reveals, it needs a channel.

## Director Plan Requirements

Before writing scene layers, define:

- beats: ordered time blocks with intent
- components: semantic scene objects
- primitives: one intentional motion per component per beat

Bad:

```text
Move everything and fade all layers at once.
```

Good:

```text
Beat 1: product card enters.
Beat 2: headline types on.
Beat 3: price badge pops.
Beat 4: call-to-action settles.
```

## ReFusion Core Icon Names

Prefer these icons when needed:

```text
arrow-down, arrow-left, arrow-right, arrow-up,
bookmark, camera, check, chevron-left, chevron-right, close,
comment, crop, heart, image, lock, mic, music, paperclip,
pause, play, plus, search, send, settings, share, sparkles,
text, user, verified, video, volume
```
