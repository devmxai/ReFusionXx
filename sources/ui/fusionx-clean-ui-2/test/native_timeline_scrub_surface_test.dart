import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/widgets/native_timeline_scrub_surface.dart';
import 'package:refusion_app/features/editor/presentation/widgets/timeline_panel.dart';

void main() {
  test('native scrub surface owns gestures only after region hit-test gating',
      () {
    expect(
      resolveNativeTimelineScrubHitTestBehavior(true),
      PlatformViewHitTestBehavior.opaque,
    );
  });

  test('native scrub surface is transparent when it has no interactive regions',
      () {
    expect(
      resolveNativeTimelineScrubHitTestBehavior(false),
      PlatformViewHitTestBehavior.transparent,
    );
  });

  test('native scrub region hit-test accepts only configured regions', () {
    const regions = <TimelineScrubViewportRegion>[
      TimelineScrubViewportRegion(left: 20, top: 10, width: 40, height: 30),
      TimelineScrubViewportRegion(left: 100, top: 80, width: 50, height: 20),
    ];

    expect(
      timelineScrubRegionsContainPoint(regions, const Offset(30, 20)),
      isTrue,
    );
    expect(
      timelineScrubRegionsContainPoint(regions, const Offset(90, 20)),
      isFalse,
    );
    expect(
      timelineScrubRegionsContainPoint(regions, const Offset(120, 90)),
      isTrue,
    );
  });
}
