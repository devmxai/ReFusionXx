# Stage 5 Scrub Investigation

Status: `RECORDED`

## Trigger

- physical-device feedback reported:
  - play became stable after the last Stage 5 fixes
  - scrub still does not provide live professional preview
  - while dragging, preview can show frame `0`
  - the final target frame only becomes visible after release

## Local Root Cause

- the current Stage 5 slice is pinned to `Media3 1.1.1` because the imported Android template still builds against `compileSdk 33`
- `Media3 1.1.1` does not expose the newer dedicated scrubbing-mode APIs
- the current Stage 5 implementation therefore falls back to:
  - `seekTo(...)`
  - `SeekParameters.CLOSEST_SYNC` during drag
  - `SeekParameters.EXACT` after release
- the fixed sample video used in Stage 5 has sparse keyframes:
  - `0.000000`
  - `7.733333`
  - `12.200000`
  - `15.333333`
- that means sync-seeking while dragging can legitimately resolve to the first keyframe for a large part of the clip, which matches the observed behavior

## Official Source Findings

- official `Media3 1.1.1` supports seek policy control through `SeekParameters`
- official docs state sync seeks are usually faster but less accurate than exact seeks
- official docs also state video seeking may require:
  - loading new data
  - flushing the decoder
  - decoding from an earlier sync frame until the target frame is reached
- newer official scrubbing APIs were added much later in `Media3 1.8.0+`

Primary references:

- [Media3 1.1.1 release notes](https://developer.android.com/jetpack/androidx/releases/media3#1.1.1)
- [Media3 1.8.0 release notes](https://developer.android.com/jetpack/androidx/releases/media3#1.8.0)
- [SeekParameters](https://developer.android.com/reference/androidx/media3/exoplayer/SeekParameters)
- [ExoPlayer.setSeekParameters](https://developer.android.com/reference/androidx/media3/exoplayer/ExoPlayer#setSeekParameters(androidx.media3.exoplayer.SeekParameters))
- [Troubleshooting: Why is seeking in my video slow?](https://developer.android.com/media/media3/exoplayer/troubleshooting#why-is-seeking-in-my-video-slow)

## Open-Source And Community Findings

- modern Android/Media3 precedent uses dedicated scrubbing mode in newer versions, not plain repeated exact seeks
- Flutter/native video precedent strongly prefers native rendering and native state ownership, with Flutter acting as UI host only
- professional editors and open-source NLEs commonly use:
  - timeline thumbnails
  - reduced-resolution preview
  - proxy media
  - shuttle playback as a distinct interaction mode
- exact frame decode on every raw drag delta is not the dominant precedent for smooth professional scrub

Supporting references:

- [Flutter platform views](https://docs.flutter.dev/platform-integration/android/platform-views)
- [video_player_android README](https://chromium.googlesource.com/external/github.com/flutter/packages/%2B/HEAD/packages/video_player/video_player_android)
- [media_kit README](https://github.com/media-kit/media-kit)
- [MediaMetadataRetriever](https://developer.android.com/reference/android/media/MediaMetadataRetriever.html)
- [Media3 inspector / FrameExtractor](https://developer.android.com/media/media3/inspector/extract-frames)
- [Kdenlive proxy clips](https://docs.kdenlive.org/en/getting_started/configure_kdenlive/configuration_proxy_clips.html)

## Engineering Conclusion

- the current Stage 5 slice can deliver:
  - correct play
  - correct final settle seek
  - native preview ownership
- the current Stage 5 slice cannot honestly guarantee:
  - DaVinci-style live bidirectional scrub preview
  - frame-accurate visual updates on every drag tick

## Approved Next Direction

To reach professional scrub behavior, the next approved technical direction is:

1. upgrade the Android toolchain so the project can adopt a newer official `Media3` with dedicated scrubbing APIs
2. keep native transport and native preview as the source of truth
3. add a dedicated scrub-preview strategy:
   - official scrubbing mode in newer `Media3`
   - timeline thumbnails / frame previews
   - optional proxy or low-GOP working media for edit responsiveness
4. treat shuttle-style playback and drag scrubbing as separate interaction modes

## Gate Decision

- `Stage 5` remains `OPEN`
- the current scrub behavior is a known architectural limitation of the present Stage 5 slice, not a closed-quality result
