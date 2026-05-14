import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/services/mcp_pending_command_layer_materializer.dart';

void main() {
  group('McpPendingCommandLayerMaterializer', () {
    test('materializes pending insert_layer solid as canvas background', () {
      const materializer = McpPendingCommandLayerMaterializer();

      final remoteLayers = materializer.materialize(
        const <Map<String, Object?>>[
          <String, Object?>{
            'id': 'command-1',
            'status': 'running',
            'command_type': 'refusion.insert_layer',
            'payload': <String, Object?>{
              'layerId': 'solid-layer-1',
              'layerKind': 'solid',
              'name': 'White Background',
              'startMs': 0,
              'durationMs': 8000,
              'zIndex': -1000,
              'payload': <String, Object?>{
                'color': '#FFFFFF',
              },
            },
          },
        ],
      );

      expect(remoteLayers, hasLength(1));
      final remoteLayer = remoteLayers.single;
      expect(remoteLayer['id'], 'solid-layer-1');
      expect(remoteLayer['layer_kind'], 'solid');
      expect(remoteLayer['z_index'], -1000);
      final payload = remoteLayer['payload'] as Map<String, Object?>;
      expect(payload['kind'], 'solid');
      expect(payload['type'], 'solid');
      expect(payload['shape'], 'rect');
      expect(payload['color'], '#FFFFFF');
      expect(payload['semanticRole'], 'background.canvas');
      expect(payload['backgroundRole'], 'canvas');
      expect(payload['mcpCommandId'], 'command-1');
    });

    test('keeps text insert identity and payload for direct local apply', () {
      const materializer = McpPendingCommandLayerMaterializer();

      final remoteLayers = materializer.materialize(
        const <Map<String, Object?>>[
          <String, Object?>{
            'id': 'command-2',
            'status': 'pending',
            'command_type': 'refusion.insert_layer',
            'payload': <String, Object?>{
              'layerId': 'text-layer-1',
              'layerKind': 'text',
              'name': 'Title',
              'payload': <String, Object?>{
                'text': 'Hello MCP',
              },
            },
          },
        ],
      );

      expect(remoteLayers, hasLength(1));
      final remoteLayer = remoteLayers.single;
      expect(remoteLayer['id'], 'text-layer-1');
      expect(remoteLayer['layer_kind'], 'text');
      final payload = remoteLayer['payload'] as Map<String, Object?>;
      expect(payload['text'], 'Hello MCP');
      expect(payload['remoteLayerId'], 'text-layer-1');
      expect(payload['operation'], 'insert_layer');
    });

    test('ignores terminal commands and unsupported command types', () {
      const materializer = McpPendingCommandLayerMaterializer();

      final remoteLayers = materializer.materialize(
        const <Map<String, Object?>>[
          <String, Object?>{
            'id': 'command-3',
            'status': 'succeeded',
            'command_type': 'refusion.insert_layer',
            'payload': <String, Object?>{
              'layerId': 'solid-layer-ignored',
              'layerKind': 'solid',
            },
          },
          <String, Object?>{
            'id': 'command-4',
            'status': 'running',
            'command_type': 'refusion.get_layers',
            'payload': <String, Object?>{
              'layerId': 'read-only-ignored',
            },
          },
        ],
      );

      expect(remoteLayers, isEmpty);
    });

    test('deduplicates repeated pending rows for the same layer id', () {
      const materializer = McpPendingCommandLayerMaterializer();

      final remoteLayers = materializer.materialize(
        const <Map<String, Object?>>[
          <String, Object?>{
            'id': 'command-5',
            'status': 'running',
            'command_type': 'refusion.insert_layer',
            'payload': <String, Object?>{
              'layerId': 'solid-layer-1',
              'layerKind': 'solid',
            },
          },
          <String, Object?>{
            'id': 'command-6',
            'status': 'running',
            'command_type': 'refusion.insert_layer',
            'payload': <String, Object?>{
              'layerId': 'solid-layer-1',
              'layerKind': 'solid',
            },
          },
        ],
      );

      expect(remoteLayers, hasLength(1));
      expect(remoteLayers.single['id'], 'solid-layer-1');
    });
  });
}
