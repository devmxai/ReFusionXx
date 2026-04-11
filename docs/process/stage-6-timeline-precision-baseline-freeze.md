# Stage 6 - Timeline Precision Baseline Freeze

## Status

Active baseline reference.

This document freezes the accepted runtime/editor baseline before timeline-precision migration begins.

It defines what later steps are not allowed to regress.

## Why This Exists

Timeline-precision work will change the editor's internal time model.

That kind of work is easy to get wrong if the project does not first freeze a "must-not-regress" baseline.

This document provides that baseline.

## Protected Baseline

The following behaviors are currently considered protected:

1. the application opens and preview initializes on device
2. imported clips can be added to the main video track
3. `live scrub` is usable enough to continue validation
4. `split/delete` currently works well enough to continue precision work
5. deleting a middle region no longer immediately collapses the renderer in the common path

## Accepted Known Imperfections

The following are still known imperfections and are not treated as regressions of this baseline:

- slight seam hold may still remain during `A -> B` playback
- timeline geometry is not yet exact enough to represent canonical cut positions
- motion/keyframe authoring is not implemented

These remain active work items.

## Forbidden Regressions

The following would reject a later precision step:

- `live scrub` stops behaving like live scrub
- `split/delete` reintroduces deleted time into playback
- a short surviving clip plays like the full original source again
- renderer/runtime collapses return during ordinary structural-edit validation
- preview stops opening or the player falls into persistent error state

## Required Validation Scenarios

Later steps must continue to pass these scenarios:

1. import `A`, split at least once, and play
2. import `A` and `B`, scrub across their seam
3. split `A` into multiple parts and delete a middle part
4. play through the surviving pieces after delete
5. reopen/play/pause without persistent transport failure

## What This Step Allows Next

With this baseline frozen, the next allowed implementation step is:

- `Step 1 - Canonical Time Type Introduction`

That step is allowed only if it changes no user-visible behavior.
