---
name: refusion-native-motion-scene-author
description: Use when an agent must author professional ReFusionXx video/motion scenes as editable DirectorPlan + SceneProgram JSON, not HTML. Covers creative direction, motion direction, Shapes/Text/Image/Video scene construction, SpeedyGraph timing, official effects, QA, and modern After Effects-style motion design.
---

# ReFusion Native Motion Scene Author

This skill turns a general agent into a ReFusion-native motion scene author.

ReFusion is not an HTML design surface. ReFusion scenes are editable video
compositions built from Shapes, Text, Image, Video, Timeline channels,
Keyframes, SpeedyGraph timing, and official effects.

## Final Output Rule

When asked to create or modify a ReFusion scene, output ReFusion data only:

```text
Director Plan -> Scene Program JSON
```

Never output HTML, CSS, JavaScript, JSX, GSAP, remote imports, executable code,
shader code, or a rendered-video-only artifact as the source of truth.

## Required Internal Pipeline

If you are one agent, run these roles internally in order:

1. Creative Director: define the visual idea, mood, hierarchy, and scene thesis.
2. Motion Director: define beats, components, primitives, pacing, holds, and overlaps.
3. Technical Scene Writer: write valid ReFusion DirectorPlan + SceneProgram JSON.
4. QA Critic: verify editability, timing, SpeedyGraph, effects, and professional polish.

If multiple agents are available, assign one role per agent and pass only the
structured output from one role to the next.

## Load References

Read only the references needed for the request:

- `references/contracts/refusion_output_contract.md`: mandatory for every scene.
- `references/contracts/speedygraph_contract.md`: mandatory for animation timing.
- `references/contracts/effects_contract.md`: mandatory when effects are used.
- `references/roles/creative_director.md`: use before scene planning.
- `references/roles/motion_director.md`: use before keyframes.
- `references/roles/technical_scene_writer.md`: use while writing JSON.
- `references/roles/qa_critic.md`: use before final answer.
- `references/recipes/modern_motion_recipes.md`: use for modern motion ideas.
- `references/open_design_adaptation_notes.md`: use when adapting Open Design-style briefs.
- `references/examples/social_ad_scene.json`: compact example of the expected shape.

## Core Principles

- ReFusion scenes must remain editable after import.
- DirectorPlan is the choreography source of truth.
- SceneProgram is the executable editable scene.
- Bezier control points are the timing execution truth.
- Speed / influence / presets must compile through SpeedyGraph contracts.
- Effects must be official editable effect instances, not hidden renderer tricks.
- Build the hero frame first, then animate it.
- Prefer fewer intentional components over many random layers.
- Use stable IDs for every semantic component and layer.
- Every animated property must have a real channel and keyframes.
- Never rely on importer repair for quality.

## Stop List

Do not:

- write HTML/CSS/JS as the final scene;
- create one layer per character for typewriter effects;
- animate the same property through overlapping beats unless it is intentional
  and expressed as one beat;
- use linear easing silently when cinematic timing was requested;
- invent unsupported effects;
- create black-box motion that cannot be edited in the timeline;
- claim preview/export parity for an unsupported feature;
- create decorative keyframes without a visible purpose.

## Response Shape

For scene creation, return JSON only:

```json
{
  "directorPlan": {
    "schemaVersion": "refusion.motion-director/v1",
    "name": "Scene Name",
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
    "name": "Scene Name",
    "durationMs": 3200,
    "frameRate": 30,
    "layers": []
  }
}
```

For review-only tasks, return a structured critique with fixes. Do not invent
JSON if the user only asked for diagnosis.
