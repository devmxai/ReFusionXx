import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/core/engine/stage5_native_transport_controller.dart';

void main() {
  test('parses live scrub capabilities map', () {
    final capabilities = parseStage5LiveScrubCapabilities(
      <String, Object?>{
        'supportsSourceDimensions': true,
        'supportsCanvasPlacement': false,
        'supportsCrop': true,
        'supportsTransformMatrix': true,
        'supportsOpacity': true,
        'supportsEffectProgramIds': false,
        'supportsDualSourceTransitionWindow': false,
        'supportsLatencyMetrics': true,
        'source': 'native-test',
      },
    );

    expect(capabilities.supportsSourceDimensions, isTrue);
    expect(capabilities.supportsCanvasPlacement, isFalse);
    expect(capabilities.supportsCrop, isTrue);
    expect(capabilities.supportsTransformMatrix, isTrue);
    expect(capabilities.supportsOpacity, isTrue);
    expect(capabilities.supportsEffectProgramIds, isFalse);
    expect(capabilities.supportsDualSourceTransitionWindow, isFalse);
    expect(capabilities.supportsLatencyMetrics, isTrue);
    expect(capabilities.source, 'native-test');
  });

  test('falls back to safe defaults when payload is invalid', () {
    final capabilities = parseStage5LiveScrubCapabilities('invalid');
    expect(capabilities.supportsSourceDimensions, isFalse);
    expect(capabilities.supportsCanvasPlacement, isFalse);
    expect(capabilities.supportsCrop, isFalse);
    expect(capabilities.supportsTransformMatrix, isFalse);
    expect(capabilities.supportsOpacity, isFalse);
    expect(capabilities.supportsEffectProgramIds, isFalse);
    expect(capabilities.supportsDualSourceTransitionWindow, isFalse);
    expect(capabilities.supportsLatencyMetrics, isFalse);
    expect(capabilities.source, 'unknown');
  });
}
