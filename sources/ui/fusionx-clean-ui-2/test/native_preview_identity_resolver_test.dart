import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/native_preview_identity_resolver.dart';

void main() {
  const resolver = NativePreviewIdentityResolver();

  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  TimelineClipData mediaClip(String id, int durationMs) {
    return TimelineClipData(
      id: id,
      type: TimelineClipType.media,
      tone: TimelineClipTone.hero,
      assetId: 'asset-$id',
      durationTime: ms(durationMs),
    );
  }

  TimelineTrackData videoTrack(List<TimelineClipData> clips) {
    return TimelineTrackData(
      kind: TimelineTrackKind.video,
      clips: clips,
    );
  }

  test('keeps native preview identity stable when a second clip is added', () {
    final firstIdentity = resolver.resolve(
      tracks: <TimelineTrackData>[
        videoTrack(<TimelineClipData>[mediaClip('a', 2000)]),
      ],
      playbackScopeId: 'scene:source-scene',
      fallbackIdentity: 'file:///a.mp4',
    );

    final secondIdentity = resolver.resolve(
      tracks: <TimelineTrackData>[
        videoTrack(<TimelineClipData>[
          mediaClip('a', 2000),
          mediaClip('b', 3000),
        ]),
      ],
      playbackScopeId: 'scene:source-scene',
      fallbackIdentity: 'file:///b.mp4',
    );

    expect(firstIdentity, 'native-preview-scope:scene:source-scene');
    expect(secondIdentity, firstIdentity);
  });

  test('falls back to asset identity when no playable video exists', () {
    final identity = resolver.resolve(
      tracks: <TimelineTrackData>[
        TimelineTrackData(
          kind: TimelineTrackKind.image,
          clips: <TimelineClipData>[
            TimelineClipData(
              id: 'image',
              type: TimelineClipType.media,
              tone: TimelineClipTone.hero,
              assetId: 'asset-image',
              durationTime: ms(2000),
            ),
          ],
        ),
      ],
      playbackScopeId: 'scene:source-scene',
      fallbackIdentity: 'image-identity',
    );

    expect(identity, 'image-identity');
  });
}
