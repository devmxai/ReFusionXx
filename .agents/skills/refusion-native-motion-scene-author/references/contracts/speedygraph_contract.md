# SpeedyGraph Timing Contract

## Principle

Bezier control points are the execution truth for cubic animation timing.
Speed, velocity, influence, preset names, and graph handles are authoring inputs
or computed views. They must compile into Bezier timing.

No animation write may bypass the central timing truth.

## Required Presets

Use these timing styles intentionally:

| Intent | Preset | Use |
|---|---|---|
| natural smooth | `easyEase` / `f9` | default professional motion |
| cinematic center energy | `slowFastSlow` | slow start, strong middle, slow end |
| soft landing | `fastSlow` / `easeOut` | fast start, slow end |
| delayed launch | `slowFast` / `easeIn` | slow start, fast end |
| plateau or hover | `fastSlowFast` | fast, slow in middle, fast again |
| snappy action | `whip` / `snap` | quick UI punches, badges, button press |
| custom curve | `customSpeedGraph` | when exact Speed Graph handles matter |

## How To Use Timing

For each animated property segment, specify either:

- a preset id;
- direct cubic Bezier control points;
- numeric speed/influence values that are meant to compile into Bezier.

Do not leave important motion as silent linear timing unless the motion is
mechanical, typewriter-like, or explicitly requested as linear.

## Professional Pacing Rules

- Use `slowFastSlow` for hero reveals, product card entrances, large rotation,
  camera-like moves, and cinematic transitions.
- Use `fastSlow` for landings, cards settling, and soft arrival.
- Use `slowFast` for exits, launches, swipes, and buildup before impact.
- Use `whip` for small accent elements, button press, snap badge, notification.
- Use linear only for progress, counters, typewriter progress, or deliberately
  mechanical motion.

## Motion Blur Relationship

Motion Blur should follow authored velocity:

- weak at the start/end of `slowFastSlow`;
- strongest near the middle of `slowFastSlow`;
- strongest near start for `fastSlow`;
- strongest near end for `slowFast`.

Do not fake cinematic blur with Gaussian Blur. Gaussian Blur is a different
effect and should not substitute for velocity-aware Motion Blur.

## Stop List

Do not:

- write `velocity` metadata without executable Bezier truth;
- mix separate easing systems;
- use random keyframe spacing instead of planned beats;
- create many micro keyframes when one well-tuned Bezier segment is enough;
- apply SpeedyGraph to clip speed ramp or time remapping. SpeedyGraph controls
  property interpolation, not media playback time.
