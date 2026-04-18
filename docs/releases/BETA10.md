# BETA10

## Status

- snapshot type: `beta tag + release`
- repository: `https://github.com/devmxai/ReFusionXx`
- tag target branch at creation time: `main`
- tag: `beta-10`
- release title: `Beta 10`
- app version: `1.0.0-beta.10+10`
- app name: `ReFusion`
- package id: `com.refusion.app`
- canonical version source:
  [pubspec.yaml](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/pubspec.yaml)
- canonical app workspace:
  [fusionx-clean-ui-2](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2)

## Purpose

`BETA10` is the explicit freeze checkpoint for the current official
`ReFusionXx` mainline.

This snapshot exists so the team can safely:

- return to a known-good GitHub checkpoint
- rebuild the official app from the canonical workspace
- install the same frozen app package on device
- resume the next feature from a documented baseline

## What This Snapshot Freezes

`BETA10` freezes the current official state where:

- the repository source of truth is `ReFusionXx`
- the canonical app identity is `ReFusion` / `com.refusion.app`
- the app version is `1.0.0-beta.10+10`
- `main` and `beta-10` resolve to the same frozen commit at release time
- the next major feature plan is documented in:
  [Scope Layer](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/docs/scope_layer.md)

## Validation

This snapshot was validated with:

- `flutter analyze`
- `./gradlew app:assembleDebug`
- on-device installation from the official workspace build output

## Rollback Meaning

If later work regresses behavior, `BETA10` is intended to be the rollback-safe
checkpoint for this exact repository and app identity state.
