import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/services/mcp_text_layer_resolution.dart';

void main() {
  group('McpTextLayerResolution', () {
    test('prioritizes remoteLayerId before targetLayerId', () {
      final resolved = McpTextLayerResolution.resolveCandidateLayerId(
        remoteLayerId: 'remote-text-1',
        payload: <String, Object?>{'targetLayerId': 'target-text-1'},
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
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
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
        exists: (layerId) => layerId == 'target-text-1',
      );
      expect(resolved, 'target-text-1');
    });

    test('supports requested/local/clip ids in strict order after layer ids',
        () {
      final resolved = McpTextLayerResolution.resolveCandidateLayerId(
        remoteLayerId: 'remote-text-1',
        payload: <String, Object?>{
          'requestedLayerId': 'requested-text-1',
          'localLayerId': 'local-text-1',
          'clipId': 'clip-text-1',
        },
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
        exists: (layerId) => layerId == 'local-text-1',
      );
      expect(resolved, 'local-text-1');
    });

    test('reads nested payload and nested updates payload candidates', () {
      final resolved = McpTextLayerResolution.resolveCandidateLayerId(
        remoteLayerId: 'remote-text-1',
        payload: const <String, Object?>{},
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{
          'targetLayerId': 'nested-target-text',
        },
        updatesPayload: const <String, Object?>{
          'layerId': 'nested-layer-text',
        },
        exists: (layerId) => layerId == 'nested-target-text',
      );
      expect(resolved, 'nested-target-text');
    });

    test('update intent with unresolved target blocks insert', () {
      final updateIntent = McpTextLayerResolution.requestsUpdate(
        payload: <String, Object?>{
          'operation': 'update_layer',
          'targetLayerId': 'missing-target',
        },
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
      );
      expect(
        McpTextLayerResolution.shouldBlockInsert(
          updateIntent: updateIntent,
          resolvedLayerId: null,
          resolvedTargetIsTextElement: false,
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
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
      );
      expect(
        McpTextLayerResolution.shouldBlockInsert(
          updateIntent: updateIntent,
          resolvedLayerId: null,
          resolvedTargetIsTextElement: false,
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
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
      );
      expect(updateIntent, isTrue);
    });

    test('set/patch operations are treated as update intent', () {
      expect(
        McpTextLayerResolution.requestsUpdate(
          payload: const <String, Object?>{'operation': 'set_text_style'},
          updates: const <String, Object?>{},
          payloadPayload: const <String, Object?>{},
          updatesPayload: const <String, Object?>{},
        ),
        isTrue,
      );
      expect(
        McpTextLayerResolution.requestsUpdate(
          payload: const <String, Object?>{'operation': 'patch_layer'},
          updates: const <String, Object?>{},
          payloadPayload: const <String, Object?>{},
          updatesPayload: const <String, Object?>{},
        ),
        isTrue,
      );
    });

    test('insert_layer with explicit target ids is treated as update intent',
        () {
      final updateIntent = McpTextLayerResolution.requestsUpdate(
        payload: const <String, Object?>{
          'operation': 'insert_layer',
          'targetLayerId': 'text-1',
        },
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
      );
      expect(updateIntent, isTrue);
    });

    test('blocks insert when resolved target exists but is not text element',
        () {
      expect(
        McpTextLayerResolution.shouldBlockInsert(
          updateIntent: true,
          resolvedLayerId: 'layer-shape-1',
          resolvedTargetIsTextElement: false,
        ),
        isTrue,
      );
      expect(
        McpTextLayerResolution.shouldBlockInsert(
          updateIntent: true,
          resolvedLayerId: 'layer-text-1',
          resolvedTargetIsTextElement: true,
        ),
        isFalse,
      );
    });
  });
}
