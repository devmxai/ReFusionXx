import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_scene_command_models.dart';
import 'package:refusion_app/features/editor/presentation/services/mcp_scene_command_dispatcher.dart';
import 'package:refusion_app/features/editor/presentation/services/professional_scene_apply_engine.dart';

void main() {
  group('ProfessionalSceneApplyEngine', () {
    test('emits proof counts for insert and update commands', () {
      final commands = <ProfessionalSceneCommand>[
        const ProfessionalSceneCommand(
          type: ProfessionalSceneCommandType.applyTextLayer,
          source: ProfessionalSceneCommandSource.mcpAgent,
          target: ProfessionalSceneCommandTarget(
            mode: ProfessionalSceneCommandTargetMode.layerId,
            id: 'text-1',
          ),
          payload: <String, Object?>{},
        ),
        const ProfessionalSceneCommand(
          type: ProfessionalSceneCommandType.applyLegacyAnimation,
          source: ProfessionalSceneCommandSource.mcpAgent,
          target: ProfessionalSceneCommandTarget(
            mode: ProfessionalSceneCommandTargetMode.layerId,
            id: 'text-1',
          ),
          payload: <String, Object?>{},
        ),
      ];

      const engine = ProfessionalSceneApplyEngine();
      final result = engine.apply(
        commands: commands,
        receivedRemoteLayers: 1,
        execute: (_) => true,
        isRepresented: (_) => true,
      );

      expect(result.didApply, isTrue);
      expect(result.hasRepresentedRemoteLayer, isTrue);
      expect(result.receipt.operationApplied, 'mixed');
      expect(result.receipt.createdLayerCount, 1);
      expect(result.receipt.updatedLayerCount, 1);
      expect(result.receipt.targetLayerIds, <String>['text-1']);
      expect(
        result.receipt.toProofMap(),
        containsPair('operationApplied', 'mixed'),
      );
    });

    test('treats shape apply with update intent as update in proof counts', () {
      final commands = <ProfessionalSceneCommand>[
        const ProfessionalSceneCommand(
          type: ProfessionalSceneCommandType.applyShapeLayer,
          source: ProfessionalSceneCommandSource.mcpAgent,
          target: ProfessionalSceneCommandTarget(
            mode: ProfessionalSceneCommandTargetMode.layerId,
            id: 'shape-1',
          ),
          payload: <String, Object?>{
            'payload': <String, Object?>{
              'operation': 'update_layer',
              'targetLayerId': 'shape-1',
              'updates': <String, Object?>{
                'width': 640,
              },
            },
          },
        ),
      ];
      const engine = ProfessionalSceneApplyEngine();
      final result = engine.apply(
        commands: commands,
        receivedRemoteLayers: 1,
        execute: (_) => true,
        isRepresented: (_) => true,
      );
      expect(result.receipt.operationApplied, 'update');
      expect(result.receipt.createdLayerCount, 0);
      expect(result.receipt.updatedLayerCount, 1);
    });
  });

  group('McpSceneCommandDispatcher', () {
    test('routes payload.motion into legacy animation apply command', () {
      const dispatcher = McpSceneCommandDispatcher();
      final commands = dispatcher.dispatchRemoteLayers(
        remoteLayers: const <Map<String, Object?>>[
          <String, Object?>{
            'id': 'text-1',
            'layer_kind': 'text',
            'payload': <String, Object?>{
              'motion': <String, Object?>{
                'in': <String, Object?>{
                  'preset': 'popUp',
                },
              },
            },
          },
        ],
        hasBackgroundVisualIntent: (_) => false,
        hasTimelineMutationIntent: (_) => false,
      );

      expect(
        commands.any(
          (command) =>
              command.type == ProfessionalSceneCommandType.applyLegacyAnimation,
        ),
        isTrue,
      );
      expect(
        commands.any(
          (command) =>
              command.type == ProfessionalSceneCommandType.applyTextLayer,
        ),
        isTrue,
      );
    });

    test('routes shape layers into applyShapeLayer command', () {
      const dispatcher = McpSceneCommandDispatcher();
      final commands = dispatcher.dispatchRemoteLayers(
        remoteLayers: const <Map<String, Object?>>[
          <String, Object?>{
            'id': 'shape-1',
            'layer_kind': 'shape',
            'payload': <String, Object?>{
              'shape': 'rect',
              'color': '#FFFFFF',
            },
          },
        ],
        hasBackgroundVisualIntent: (_) => false,
        hasTimelineMutationIntent: (_) => false,
      );
      expect(commands, hasLength(1));
      expect(
        commands.first.type,
        ProfessionalSceneCommandType.applyShapeLayer,
      );
      expect(commands.first.target.id, 'shape-1');
    });
  });
}
