# ReFusion Effects Contract

## Principle

Effects are editable scene data. They are not hidden overlays, HTML filters, CSS
effects, bitmap tricks, or one-off renderer hacks.

Use official ReFusion effect concepts only. If an effect is unsupported, state
that clearly or approximate with supported editable primitives.

## Current Important Effects

Use these names and meanings consistently:

- `motion_blur`: velocity-aware transform motion blur.
- `motion_tile` / `edge_fill`: fills blank canvas areas created by rotation,
  scale, position, or blur sampling.
- `gaussian_blur`: regular blur.
- transform properties: position, scale, rotation, opacity, anchor when supported.

## Motion Tile / Edge Fill

Use Motion Tile when rotation, scale-down, or motion blur may expose blank
corners or black edges.

Expected behavior:

- fills outside-source blank areas;
- supports mirrored continuation when mirror edges are requested;
- does not change the rotation pivot;
- does not mutate the authored transform;
- should appear before Motion Blur in visual chain when blur needs filled edges.

## Motion Blur

Use Motion Blur when movement speed should be visible:

- spin transitions;
- fast swipes;
- zoom pushes;
- position whip;
- scale burst;
- cinematic card movement.

Motion Blur must be driven by authored SpeedyGraph velocity, not random amount
values only.

## Ordering Guidance

When combining these effects:

```text
Motion Tile / Edge Fill
-> Motion Blur
-> Gaussian Blur
```

This avoids blurring black gaps into visible rings.

## Stop List

Do not:

- invent an effect name that ReFusion cannot import;
- use CSS filters;
- claim After Effects parity if the effect is only approximate;
- use an overlay layer as the source of effect truth;
- use Gaussian Blur to pretend Motion Blur exists;
- apply Motion Tile in a way that changes transform anchor or center.
