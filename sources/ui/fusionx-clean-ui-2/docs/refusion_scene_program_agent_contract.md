# ReFusion Scene Program Agent Contract

This document is the strict prompt contract for agents that generate editable
motion graphics for ReFusion.

Status: V1 foundation.

Important: this contract must not touch, rewrite, or degrade Live Scrub. Scripts
created from this contract become editable motion data. They are not executable
code and they must not create private preview paths.

## Purpose

Agents should generate `ReFusionSceneProgram` JSON that can be imported,
validated, lowered into `MotionAuthoringBundle`, projected into timeline lanes,
and edited manually inside scoped timelines.

The target is not a web runtime, not JSX, and not a hidden animation file. The
target is editable ReFusion motion data.

## Hard Rules

- Output JSON only.
- Do not output JSX, JavaScript, TypeScript, HTML, CSS, expressions, or shader source.
- Do not include executable fields such as `code`, `script`, `function`, `eval`,
  `imports`, `remoteImports`, `jsx`, `javascript`, or `shaderSource`.
- Always include `"kind": "refusion.sceneProgram"`.
- Always include `"schemaVersion": "refusion.scene-program/v1"`.
- Always include a stable `"id"`.
- Always include `"durationMs"` as a positive integer.
- Every channel must have a stable `"id"`, a `"targetId"`, a supported
  `"property"`, and at least one keyframe.
- Keyframes should use `"timeMs"` for deterministic timing.
- Every keyframe value must match the property type.
- Motion must be readable after import as normal keyframes.

## V1 Supported Properties

These are the supported properties for editable scalar keyframes:

- `transform.position.x`
- `transform.position.y`
- `transform.scale.x`
- `transform.scale.y`
- `transform.rotation.degrees`
- `visual.opacity`
- `visual.blur.amount`
- `visual.blur.horizontal`
- `visual.blur.vertical`
- `visual.blur.mix`
- `visual.blur.edgeMode`
- `visual.blur.crop`
- `shape.width`
- `shape.height`

Use scalar numbers:

- opacity: `0.0` to `1.0`
- scale: `1.0` means 100%
- rotation: degrees
- position: canvas-space scalar values
- blur: engine scalar values

## V1 Supported Elements

Elements can currently declare these kinds:

- `text`
- `shape`
- `image`
- `video`

For text, include `"text"` with the displayed string.

## Interpolation

Use one of these strings:

- `hold`
- `linear`
- `easeIn`
- `easeOut`
- `easeInOut`
- `easyEase`
- `spring`
- `bounce`
- `elastic`

For custom interpolation objects, use:

```json
{"kind": "spring", "stiffness": 260, "damping": 22}
```

```json
{"kind": "cubicBezier", "x1": 0.3333, "y1": 0, "x2": 0.6667, "y2": 1}
```

## Recommended Agent Prompt

Use this when asking another agent to generate a ReFusion motion script:

```text
Generate a ReFusionSceneProgram JSON file only.

Rules:
- Use kind "refusion.sceneProgram".
- Use schemaVersion "refusion.scene-program/v1".
- Do not output JSX, JavaScript, CSS, HTML, expressions, or executable code.
- Do not include fields named code, script, function, eval, imports,
  remoteImports, jsx, javascript, or shaderSource.
- Make all motion editable as keyframes.
- Use timeMs for all keyframe times.
- Use supported scalar properties only.
- For opacity use 0.0 to 1.0.
- For scale use 1.0 as 100%.
- For rotation use degrees.
- Use spring/easeOut/easyEase where motion should feel professional.
- Return JSON only, with no markdown wrapper.
```

## Example: Text Pop

Machine-checked JSON examples are available in:

- `docs/examples/refusion_scene_program/text_pop_intro.json`
- `docs/examples/refusion_scene_program/lower_third_slide.json`
- `docs/examples/refusion_scene_program/promo_card_motion.json`
- `docs/examples/refusion_scene_program/kinetic_shape_reveal.json`

```json
{
  "kind": "refusion.sceneProgram",
  "schemaVersion": "refusion.scene-program/v1",
  "id": "text-pop-intro",
  "name": "Text Pop Intro",
  "durationMs": 1600,
  "elements": [
    {
      "id": "title",
      "kind": "text",
      "text": "FUSION",
      "range": {"startMs": 0, "endMs": 1600}
    }
  ],
  "channels": [
    {
      "id": "title.opacity",
      "targetId": "title",
      "property": "visual.opacity",
      "keyframes": [
        {"timeMs": 0, "value": 0, "interpolation": "linear"},
        {"timeMs": 180, "value": 1, "interpolation": "easeOut"},
        {"timeMs": 1400, "value": 1, "interpolation": "linear"}
      ]
    },
    {
      "id": "title.scale.x",
      "targetId": "title",
      "property": "transform.scale.x",
      "keyframes": [
        {"timeMs": 0, "value": 0.72, "interpolation": {"kind": "spring", "stiffness": 260, "damping": 20}},
        {"timeMs": 360, "value": 1.08, "interpolation": "easeOut"},
        {"timeMs": 520, "value": 1.0, "interpolation": "easyEase"}
      ]
    },
    {
      "id": "title.scale.y",
      "targetId": "title",
      "property": "transform.scale.y",
      "keyframes": [
        {"timeMs": 0, "value": 0.72, "interpolation": {"kind": "spring", "stiffness": 260, "damping": 20}},
        {"timeMs": 360, "value": 1.08, "interpolation": "easeOut"},
        {"timeMs": 520, "value": 1.0, "interpolation": "easyEase"}
      ]
    },
    {
      "id": "title.position.y",
      "targetId": "title",
      "property": "transform.position.y",
      "keyframes": [
        {"timeMs": 0, "value": 90, "interpolation": "easeOut"},
        {"timeMs": 520, "value": 0, "interpolation": "easyEase"}
      ]
    }
  ]
}
```

## Current Limits

V1 intentionally does not yet support:

- JSX or web component code.
- direct transition objects.
- shader source import.
- arbitrary JavaScript expressions.
- non-scalar keyframe values such as rects and points.
- hidden generated motion that cannot be shown as keyframes.

Those features must be added through documented schema revisions, not by
creating side paths.

## Acceptance Checklist

Before using a generated script:

- It validates with `ReFusionSceneProgramImportService`.
- It lowers with `ReFusionSceneProgramMotionLoweringService`.
- It projects with `MotionAuthoringBundleTimelineAdapter`.
- Keyframes are visible as editable lanes.
- Preview, scrub, playback, and export eventually read the same graph.
- Live Scrub remains protected.
