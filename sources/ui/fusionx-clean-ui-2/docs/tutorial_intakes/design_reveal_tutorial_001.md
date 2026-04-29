# Tutorial Intake 001: Design Reveal Study

Status: first official tutorial-derived capability intake  
Source type: After Effects tutorial transcript supplied by the user  
Reference frame: `/Users/mx/Desktop/Screenshot 2026-04-29 at 2.40.37 AM.png`  
Present demo: `Design Reveal Study`

## Visual Goal

Build a reusable professional title-reveal grammar inspired by the tutorial:

```text
red ramp background
-> white circular shape enters and leads the eye
-> shape morphs between circle / pill / dot
-> bold white title is revealed with a masked/type-on feeling
-> soft dark-red shadow grows under the title
-> timing uses snappy eased graph-like motion
```

The goal is not to clone the tutorial as a locked preset. The goal is to
extract general tools that can be reused in other scenes, prompts, and manual
Layer Scope edits.

## Extracted Tools

| Tutorial tool | ReFusion capability | Category | Current status |
| --- | --- | --- | --- |
| Gradient Ramp / Radial Ramp | `effects.gradientRamp` | Effects | planned |
| Align center / anchor center | `layout.alignCenter`, `transform.anchorPoint` | Layout / Transform | partially supported through centered canvas coordinates |
| Shape circle to rectangle | `shape.morphCircleRect` | Shape | partially supported through `width`, `height`, `cornerRadius` channels |
| Position animation | `transform.position` | Transform | preview-ready / editable |
| Opacity animation | `transform.opacity` | Transform | preview-ready / editable |
| Easy Ease / speed graph | `choreography.snappyEase`, `interpolation.graphHandle` | Choreography | partially supported through named easings |
| Frame-by-frame text mask | `mask.movingReveal` | Mask | planned |
| Text reveal | `text.typewriter`, future `text.rangeSelector` | Text | typewriter preview-ready; range selector planned |
| Soft ellipse shadow + Gaussian blur | `effects.softShadow` | Effects | partially supported through blurred shape approximation |

## Present Demo Boundary

`Design Reveal Study` intentionally uses only capabilities already available in
the current Scene Program path:

- layered shape fills to approximate a red ramp;
- `width`, `height`, and `cornerRadius` channels to approximate circle/pill/dot
  morphing;
- `typewriterProgress` to approximate a reveal in place of a true moving mask;
- blurred rounded shape to approximate a soft shadow.

It does not claim full After Effects parity yet. The missing reusable engine
work is recorded below.

## Capability Pack Proposal

### Design Reveal Pack V1

1. `effects.gradientRamp`
   - radial and linear ramp modes;
   - start/end color;
   - start/end points;
   - scatter/noise control;
   - preview/export parity.

2. `mask.movingReveal`
   - rectangular mask path;
   - mask position keyframes;
   - mask expansion/feather;
   - inverted mask support;
   - compatible with text, shape, image, and group targets.

3. `effects.softShadow`
   - shadow color;
   - blur radius;
   - spread/scale;
   - offset;
   - opacity;
   - reusable on text, shapes, images, and groups.

4. `shape.morphCircleRect`
   - high-level control that compiles to `width`, `height`, and `cornerRadius`;
   - supports circle, pill, rectangle, and dot states;
   - preserves editable low-level keyframes.

5. `text.rangeSelector`
   - After Effects-style range selector for position, opacity, tracking, and
     per-character reveals;
   - must stay editable in Layer Scope.

6. `choreography.snappyEase`
   - graph-handle inspired easing preset;
   - must compile into explicit interpolation metadata rather than hidden UI.

## Agent Rule Update

When an agent sees a request like this tutorial, it must not generate five
random layers with overlapping unrelated animation. It must write a beat plan:

```text
background enter
-> shape lead-in
-> title reveal
-> readable hold
-> optional exit or transition
```

Every layer must finish its current motion before the next dependent beat
consumes the viewer's attention, unless the director plan explicitly marks the
overlap as a handoff.

## Verification Notes

The first checkpoint only adds documentation and a Present demo. It does not
touch protected Live Scrub files, native playback, preview transport, or export
rendering.

Manual test after install:

1. Open `Present`.
2. Tap `Design Reveal Study`.
3. Confirm one editable Scene Clip appears on the root timeline.
4. Double tap the Scene Clip.
5. Confirm internal layers include red field, title, driver shape, and shadow.
6. Double tap a layer to inspect editable keyframes.

Known expected gap: the reveal is an approximation until real `mask.movingReveal`
and `effects.gradientRamp` exist.
