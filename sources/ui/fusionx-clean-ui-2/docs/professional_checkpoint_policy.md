# Professional Checkpoint And GitHub Push Policy

Status: mandatory development policy  
Applies to: all ReFusion implementation work  
Package: `com.refusion.app`

## Purpose

ReFusion development must be reversible.

Every meaningful implementation step must leave a clear GitHub checkpoint so the team can return to the previous stable point without guessing, rebuilding from memory, or losing a working feature.

This is not optional polish. It is part of the professional safety system for the app.

## Strict Rule

After every completed build step, create and push a focused checkpoint.

```text
implement scoped change
-> verify the smallest relevant behavior
-> commit only the related files
-> push the branch to GitHub
-> record the result in the response
```

Do not wait for a large feature to finish before pushing.

This policy is also mirrored in the local Codex skill
`refusion-development-guardrails`. If the skill is available, it must be used
for ReFusion implementation work. If the skill is unavailable, this document is
still authoritative.

## What Counts As A Build Step

A build step is any meaningful change that alters behavior, architecture, UI, timeline state, media playback, export, script import, keyframes, effects, or documentation that controls future implementation.

Examples:

- timeline clock change,
- Live Scrub adapter change,
- keyframe operation change,
- transition engine change,
- effect evaluator change,
- script importer change,
- scope timeline behavior change,
- native playback or preview fix,
- documentation that changes official implementation rules.

Tiny investigation-only reads do not require a checkpoint. Any file edit that should be preserved does.

## Required Checkpoint Contents

Each checkpoint must include:

- focused files only,
- a clear commit message,
- branch pushed to GitHub,
- verification notes,
- known risks or unverified items.

Commit message format:

```text
checkpoint: <short behavior or plan name>
```

Examples:

```text
checkpoint: stabilize play after live scrub
checkpoint: document unified motion keyframe engine
checkpoint: add transition keyframe add flow
checkpoint: protect timeline clock scope projection
```

## Branch Rules

- Do not push unstable development directly to `main`.
- Work on a named development branch.
- Keep `main` as the stable integration line.
- If a regression appears, prefer a corrective commit or `git revert` over destructive history rewrites.
- Do not use `git reset --hard` or checkout-away user changes unless explicitly requested.

## Dirty Worktree Rules

Before every checkpoint:

1. Run `git status --short`.
2. Identify unrelated uncommitted changes.
3. Commit only files related to the current completed step.
4. Do not stage unrelated files.
5. If the checkpoint depends on unrelated dirty files, state that clearly before pushing.

This protects user work and prevents accidental GitHub snapshots that mix unrelated features.

## Verification Rules

Use the smallest verification that proves the checkpoint.

Typical gates:

- documentation-only: no build required, but inspect references with `rg`;
- Dart/domain change: targeted `flutter test`;
- Flutter UI change: `flutter analyze` plus targeted test when available;
- Android/native/media change: `flutter build apk --debug`;
- device behavior change: install on connected device and ask for real-device validation.

If verification cannot run, the checkpoint response must say why.

## Response Requirement

After every checkpoint push, the response must include:

- branch name,
- commit hash,
- commit message,
- files included,
- verification performed,
- push result,
- rollback note.

Minimum rollback note:

```text
Rollback: git revert <commit-hash>
```

## Live Scrub Protection

Checkpoint policy does not override Live Scrub safety.

If a change touches the protected Live Scrub path, it must also satisfy:

- `docs/live_scrub_migration_mandate.md`
- `docs/professional_refusion_motion_keyframe_engine.md`

No checkpoint may hide a Live Scrub regression.

## Agent Instruction

Any agent working on this repository must treat this file as mandatory.

Before implementation:

1. read this policy,
2. read the relevant feature plan,
3. check `git status --short`,
4. identify unrelated dirty files,
5. implement the smallest safe step,
6. verify,
7. checkpoint and push.

If the user explicitly asks not to push, document the local checkpoint state and wait.

For tasks near timeline, keyframes, transitions, preview, playback, export, or
script import, the agent must also state whether the change touches protected
Live Scrub files. If it does, the task must stop unless the user explicitly
approved that exact Live Scrub change.
