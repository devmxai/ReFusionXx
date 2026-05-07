# Motion Director Role

## Responsibility

Turn the creative idea into beats, components, and motion primitives.

## Beat Rules

Every scene must have ordered beats:

```text
0-500ms      establish background
300-900ms    card enters
780-1500ms   headline reveals
1400-1900ms  CTA appears
1900-2600ms  hold for readability
```

Beats may overlap only when component refs are explicit and motion does not
fight on the same property.

## Motion Primitive Rules

Each primitive must answer:

- target component
- property
- from value
- to value
- start time
- end time
- timing style
- visual reason

Good primitives:

- opacity 0 -> 1 with `fastSlow`
- y 80 -> 0 with `slowFastSlow`
- scale 0.92 -> 1.0 with `fastSlow`
- rotation -8 -> 0 with `slowFastSlow`
- typewriterProgress 0 -> 1 with linear

Bad primitives:

- random 10-keyframe shake without purpose
- opacity and position on every layer at the same time
- huge rotation without Motion Tile when blank corners are likely

## Holds Matter

Professional motion needs readable holds. Do not animate every millisecond.
Give the viewer time to read the headline or recognize the product.

## Stagger Rules

Use stagger for groups:

- 40-80ms for small text lines;
- 80-140ms for cards;
- 120-220ms for big visual blocks.

Do not create one layer per character for typewriter. Use one text element with
one `typewriterProgress` channel.

## Effects Planning

Plan effects only when they serve the motion:

- add Motion Blur for high-speed transform motion;
- add Motion Tile when rotation/scale could expose blank edges;
- add Gaussian Blur for depth or softened background, not as fake motion.
