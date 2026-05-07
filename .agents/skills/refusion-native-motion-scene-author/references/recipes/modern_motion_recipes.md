# Modern ReFusion Motion Recipes

Use these as starting patterns. Always adapt to the prompt.

## Premium App Promo

Components:

- soft background
- phone/card body
- product screenshot placeholder
- headline
- CTA
- accent glow or ring

Motion:

- background settles slowly;
- card moves y 120 -> 0, scale 0.94 -> 1.0, `slowFastSlow`;
- headline typewriterProgress 0 -> 1, linear;
- CTA opacity 0 -> 1 and scale 0.92 -> 1.0, `fastSlow`;
- optional Motion Blur on card entrance.

## Social Ad Card

Components:

- background color/gradient represented as shape layers;
- central product/object;
- large headline;
- small proof badge;
- CTA strip.

Motion:

- central object enters first;
- headline follows with stagger;
- badge snaps with `whip`;
- end hold at least 700ms.

## Kinetic Title Reveal

Components:

- background;
- oversized text;
- mask-like reveal shape;
- accent line or circle.

Motion:

- reveal shape expands;
- text opacity/position follows;
- accent line trims or scales;
- use `slowFastSlow` for main reveal and `fastSlow` for settle.

## Spin Transition Concept

Components:

- source video/image layer;
- transition target or next card;
- optional Motion Tile;
- Motion Blur.

Motion:

- rotation around exact visual center;
- use `slowFastSlow` timing;
- enable Motion Tile / Edge Fill before Motion Blur when blank corners are likely;
- keep final frame stable and readable.

## Typewriter Prompt Scene

Components:

- prompt shell;
- text element;
- send button;
- reveal circle or card.

Motion:

- shell enters with y/opacity, `fastSlow`;
- text uses one `typewriterProgress` channel, linear;
- send button press uses scale 1 -> 0.92 -> 1, `whip`;
- reveal circle expands, `slowFastSlow`.

## Do Not Do

- no one-layer-per-letter typewriter;
- no random bounces on every object;
- no all-elements fade/scale together;
- no motion without a readable hero frame;
- no unsupported effects to imitate web/CSS tricks.
