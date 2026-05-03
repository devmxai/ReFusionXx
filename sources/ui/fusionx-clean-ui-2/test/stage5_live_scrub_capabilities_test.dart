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

  test('maps transport capabilities into descriptor capabilities', () {
    const capabilities = Stage5LiveScrubCapabilities(
      supportsSourceDimensions: true,
      supportsCanvasPlacement: true,
      supportsCrop: false,
      supportsTransformMatrix: true,
      supportsOpacity: true,
      supportsEffectProgramIds: false,
      supportsDualSourceTransitionWindow: false,
      supportsLatencyMetrics: true,
      source: 'stage5_read_only_capability_handshake_v1',
    );

    final descriptorCapabilities = capabilities.toDescriptorCapabilities();
    expect(descriptorCapabilities.supportsSourceDimensions, isTrue);
    expect(descriptorCapabilities.supportsCanvasPlacement, isTrue);
    expect(descriptorCapabilities.supportsCrop, isFalse);
    expect(descriptorCapabilities.supportsTransformMatrix, isTrue);
    expect(descriptorCapabilities.supportsOpacity, isTrue);
    expect(descriptorCapabilities.supportsEffectProgramIds, isFalse);
    expect(descriptorCapabilities.supportsDualSourceTransitionWindow, isFalse);
    expect(descriptorCapabilities.supportsLatencyMetrics, isTrue);
    expect(
      descriptorCapabilities.source,
      'stage5_read_only_capability_handshake_v1',
    );
  });
}
