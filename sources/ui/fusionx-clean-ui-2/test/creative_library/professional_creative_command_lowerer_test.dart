import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/models/professional_creative_library_registry_models.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_command_lowerer.dart';

void main() {
  group('PNCLE-06 Lowering And Timeline Projection', () {
    const lowerer = ProfessionalCreativeCommandLowerer();

    test('insert command lowers to graph node + timeline clip', () {
      final result = lowerer.lower(
        envelopes: const <ProfessionalSceneCommandEnvelope>[
          ProfessionalSceneCommandEnvelope(
            commandFamily: CommandFamilyDefinition.insertComponent,
            targetId: 'layer.text.1',
            payload: <String, Object?>{
              'capabilityId': r'$component.text.title',
              'startMs': 0,
              'durationMs': 3000,
            },
            surface: SupportedEntrySurface.mcp,
            dryRunEligible: true,
          ),
        ],
      );

      expect(result.ok, isTrue);
      expect(result.graphNodes.length, 1);
      expect(result.timelineClips.length, 1);
      expect(result.timelineVisible, isTrue);
      expect(result.graphVisible, isTrue);
    });

    test('effect command lowers to effect instance and host graph node', () {
      final result = lowerer.lower(
        envelopes: const <ProfessionalSceneCommandEnvelope>[
          ProfessionalSceneCommandEnvelope(
            commandFamily: CommandFamilyDefinition.applyEffect,
            targetId: 'layer.video.1',
            payload: <String, Object?>{
              'capabilityId': r'$effect.motionBlur',
              'amount': 0.6,
            },
            surface: SupportedEntrySurface.mcp,
            dryRunEligible: true,
          ),
        ],
      );

      expect(result.ok, isTrue);
      expect(result.effectInstances.length, 1);
      expect(result.graphNodes.length, 1);
      expect(result.timelineClips, isEmpty);
    });

    test('motion command lowers to motion channel and host graph node', () {
      final result = lowerer.lower(
        envelopes: const <ProfessionalSceneCommandEnvelope>[
          ProfessionalSceneCommandEnvelope(
            commandFamily: CommandFamilyDefinition.applyMotionRecipe,
            targetId: 'layer.text.1',
            payload: <String, Object?>{
              'capabilityId': r'$motion.popUpSpring',
              'durationMs': 700,
            },
            surface: SupportedEntrySurface.mcp,
            dryRunEligible: true,
          ),
        ],
      );

      expect(result.ok, isTrue);
      expect(result.motionChannels.length, 1);
      expect(result.graphNodes.length, 1);
      expect(result.timelineClips, isEmpty);
    });

    test('update command does not create duplicate clips for same target', () {
      final result = lowerer.lower(
        envelopes: const <ProfessionalSceneCommandEnvelope>[
          ProfessionalSceneCommandEnvelope(
            commandFamily: CommandFamilyDefinition.updateComponent,
            targetId: 'layer.text.1',
            payload: <String, Object?>{
              'capabilityId': r'$component.text.title',
              'text': 'TEST',
            },
            surface: SupportedEntrySurface.mcp,
            dryRunEligible: true,
          ),
          ProfessionalSceneCommandEnvelope(
            commandFamily: CommandFamilyDefinition.updateComponent,
            targetId: 'layer.text.1',
            payload: <String, Object?>{
              'capabilityId': r'$component.text.title',
              'fontSize': 96,
            },
            surface: SupportedEntrySurface.mcp,
            dryRunEligible: true,
          ),
        ],
      );

      expect(result.ok, isTrue);
      expect(result.timelineClips.length, 1);
      expect(result.updatedTargetIds, contains('layer.text.1'));
    });

    test('empty target fails closed', () {
      final result = lowerer.lower(
        envelopes: const <ProfessionalSceneCommandEnvelope>[
          ProfessionalSceneCommandEnvelope(
            commandFamily: CommandFamilyDefinition.insertComponent,
            targetId: '',
            payload: <String, Object?>{},
            surface: SupportedEntrySurface.mcp,
            dryRunEligible: true,
          ),
        ],
      );

      expect(result.ok, isFalse);
      expect(result.blockerCode, 'TARGET_REQUIRED');
    });
  });
}
