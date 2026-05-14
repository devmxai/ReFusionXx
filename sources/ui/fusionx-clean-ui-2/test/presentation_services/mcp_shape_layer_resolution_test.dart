import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/services/mcp_shape_layer_resolution.dart';

void main() {
  group('McpShapeLayerResolution', () {
    test('prioritizes remoteLayerId before targetLayerId', () {
      final resolved = McpShapeLayerResolution.resolveCandidateLayerId(
        remoteLayerId: 'remote-shape-1',
        payload: <String, Object?>{'targetLayerId': 'target-shape-1'},
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
        exists: (layerId) =>
            layerId == 'remote-shape-1' || layerId == 'target-shape-1',
      );
      expect(resolved, 'remote-shape-1');
    });

    test('falls back to targetLayerId when remote id is not resolvable', () {
      final resolved = McpShapeLayerResolution.resolveCandidateLayerId(
        remoteLayerId: 'remote-shape-1',
        payload: <String, Object?>{'targetLayerId': 'target-shape-1'},
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
        exists: (layerId) => layerId == 'target-shape-1',
      );
      expect(resolved, 'target-shape-1');
    });

    test('insert intent with no target remains insert', () {
      final updateIntent = McpShapeLayerResolution.requestsUpdate(
        operation: 'insert_layer',
        payload: const <String, Object?>{
          'color': '#FFFFFF',
          'width': 1080,
          'height': 1920,
        },
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
        aliases: const <String>[],
      );
      expect(updateIntent, isFalse);
    });

    test('insert with explicit target is treated as update intent', () {
      final updateIntent = McpShapeLayerResolution.requestsUpdate(
        operation: 'insert_layer',
        payload: const <String, Object?>{
          'targetLayerId': 'shape-layer-1',
          'color': '#FF0000',
        },
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
        aliases: const <String>[],
      );
      expect(updateIntent, isTrue);
    });

    test('update patch map without insert keyword is update intent', () {
      final updateIntent = McpShapeLayerResolution.requestsUpdate(
        operation: '',
        payload: const <String, Object?>{},
        updates: const <String, Object?>{
          'payload': <String, Object?>{'opacity': 0.8}
        },
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{'opacity': 0.8},
        aliases: const <String>[],
      );
      expect(updateIntent, isTrue);
    });

    test('unresolved update blocks insert fail-closed', () {
      final updateIntent = McpShapeLayerResolution.requestsUpdate(
        operation: 'update_layer',
        payload: const <String, Object?>{'targetLayerId': 'missing-shape'},
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
        aliases: const <String>['missing-shape'],
      );
      expect(
        McpShapeLayerResolution.shouldBlockInsert(
          updateIntent: updateIntent,
          resolvedLayerId: null,
          resolvedTargetIsShapeElement: false,
        ),
        isTrue,
      );
    });

    test('resolved shape update does not block insert path', () {
      expect(
        McpShapeLayerResolution.shouldBlockInsert(
          updateIntent: true,
          resolvedLayerId: 'shape-layer-1',
          resolvedTargetIsShapeElement: true,
        ),
        isFalse,
      );
    });
  });
}
