import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/core/engine/stage5_native_transport_controller.dart';

void main() {
  test('parses stage5 live scrub performance snapshot payload', () {
    final snapshot = parseStage5LiveScrubPerformanceSnapshot(
      <String, Object?>{
        'estimatedFrameRequestRateFps': 29.7,
        'avgDecoderConfigureLatencyMs': 7.2,
        'avgFrameRenderLatencyMs': 15.8,
        'droppedFrameCountEstimate': 2,
        'crossSourceWarmupReady': true,
      },
    );

    expect(snapshot.frameRequestRateFps, 29.7);
    expect(snapshot.nativeDecodeRebindLatencyMs, 7.2);
    expect(snapshot.framePresentationLatencyMs, 15.8);
    expect(snapshot.droppedFrameCount, 2);
    expect(snapshot.crossSourceWarmupReady, isTrue);
  });

  test('falls back to empty snapshot when payload is invalid', () {
    final snapshot = parseStage5LiveScrubPerformanceSnapshot('invalid');
    expect(snapshot.frameRequestRateFps, isNull);
    expect(snapshot.nativeDecodeRebindLatencyMs, isNull);
    expect(snapshot.framePresentationLatencyMs, isNull);
    expect(snapshot.droppedFrameCount, isNull);
    expect(snapshot.crossSourceWarmupReady, isFalse);
  });
}
