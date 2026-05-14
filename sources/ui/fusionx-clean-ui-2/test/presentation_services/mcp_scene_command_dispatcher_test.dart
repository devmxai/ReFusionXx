import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_scene_command_models.dart';
import 'package:refusion_app/features/editor/presentation/services/mcp_scene_command_dispatcher.dart';

void main() {
  group('McpSceneCommandDispatcher', () {
    test('applies text layer before legacy animation on same remote layer', () {
      const dispatcher = McpSceneCommandDispatcher();

      final commands = dispatcher.dispatchRemoteLayers(
        remoteLayers: const <Map<String, Object?>>[
          <String, Object?>{
            'id': 'remote-text-1',
            'layer_kind': 'text',
            'payload': <String, Object?>{
              'text': 'Hello MCP',
              'motion': <String, Object?>{
                'in': <String, Object?>{'preset': 'popUp'},
              },
            },
          },
        ],
        hasBackgroundVisualIntent: (_) => false,
        hasTimelineMutationIntent: (_) => false,
      );

      expect(commands, hasLength(2));
      expect(commands[0].type, ProfessionalSceneCommandType.applyTextLayer);
      expect(
        commands[1].type,
        ProfessionalSceneCommandType.applyLegacyAnimation,
      );
    });

    test('routes shape background intent to solid apply before generic shape',
        () {
      const dispatcher = McpSceneCommandDispatcher();

      final commands = dispatcher.dispatchRemoteLayers(
        remoteLayers: const <Map<String, Object?>>[
          <String, Object?>{
            'id': 'remote-shape-bg-1',
            'layer_kind': 'shape',
            'payload': <String, Object?>{
              'shape': 'rect',
              'operation': 'set_background',
            },
          },
        ],
        hasBackgroundVisualIntent: (_) => true,
        hasTimelineMutationIntent: (_) => false,
      );

      expect(commands, hasLength(1));
      expect(commands.first.type, ProfessionalSceneCommandType.applySolidLayer);
    });

    test('prefers explicit targetLayerId over remote command id for updates',
        () {
      const dispatcher = McpSceneCommandDispatcher();

      final commands = dispatcher.dispatchRemoteLayers(
        remoteLayers: const <Map<String, Object?>>[
          <String, Object?>{
            'id': 'command-row-1',
            'layer_kind': 'text',
            'payload': <String, Object?>{
              'operation': 'update_layer',
              'targetLayerId': 'text-layer-live-1',
              'text': 'Updated',
            },
          },
        ],
        hasBackgroundVisualIntent: (_) => false,
        hasTimelineMutationIntent: (_) => false,
      );

      expect(commands, hasLength(1));
      expect(commands.first.type, ProfessionalSceneCommandType.applyTextLayer);
      expect(commands.first.target.id, 'text-layer-live-1');
    });
  });
}
