import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/services/mcp_text_layer_resolution.dart';

void main() {
  group('McpTextLayerResolution', () {
    test('prioritizes remoteLayerId before targetLayerId', () {
      final resolved = McpTextLayerResolution.resolveCandidateLayerId(
        remoteLayerId: 'remote-text-1',
        payload: <String, Object?>{'targetLayerId': 'target-text-1'},
        updates: const <String, Object?>{},
        nestedPayload: const <String, Object?>{},
        exists: (layerId) =>
            layerId == 'remote-text-1' || layerId == 'target-text-1',
      );
      expect(resolved, 'remote-text-1');
    });

    test('falls back to targetLayerId when remoteLayerId is not resolvable',
        () {
      final resolved = McpTextLayerResolution.resolveCandidateLayerId(
        remoteLayerId: 'remote-text-1',
        payload: <String, Object?>{'targetLayerId': 'target-text-1'},
        updates: const <String, Object?>{},
        nestedPayload: const <String, Object?>{},
        exists: (layerId) => layerId == 'target-text-1',
      );
      expect(resolved, 'target-text-1');
    });

    test('update intent with unresolved target blocks insert', () {
      final updateIntent = McpTextLayerResolution.requestsUpdate(
        payload: <String, Object?>{
          'operation': 'update_layer',
          'targetLayerId': 'missing-target',
        },
        updates: const <String, Object?>{},
        nestedPayload: const <String, Object?>{},
      );
      expect(
        McpTextLayerResolution.shouldBlockInsert(
          updateIntent: updateIntent,
          resolvedLayerId: null,
        ),
        isTrue,
      );
    });

    test('insert intent without target does not block insert', () {
      final updateIntent = McpTextLayerResolution.requestsUpdate(
        payload: const <String, Object?>{
          'operation': 'insert_layer',
        },
        updates: const <String, Object?>{},
        nestedPayload: const <String, Object?>{},
      );
      expect(
        McpTextLayerResolution.shouldBlockInsert(
          updateIntent: updateIntent,
          resolvedLayerId: null,
        ),
        isFalse,
      );
    });

    test('update intent from targetLayerId is detected without operation tag',
        () {
      final updateIntent = McpTextLayerResolution.requestsUpdate(
        payload: const <String, Object?>{
          'targetLayerId': 'layer-123',
        },
        updates: const <String, Object?>{},
        nestedPayload: const <String, Object?>{},
      );
      expect(updateIntent, isTrue);
    });
  });
}
