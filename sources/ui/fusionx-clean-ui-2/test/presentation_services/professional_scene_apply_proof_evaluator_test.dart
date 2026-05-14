import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_scene_command_models.dart';
import 'package:refusion_app/features/editor/presentation/services/professional_scene_apply_proof_evaluator.dart';

void main() {
  group('ProfessionalSceneApplyProofEvaluator', () {
    const evaluator = ProfessionalSceneApplyProofEvaluator();

    test('buildSuccessProof uses dynamic apply state', () {
      const receipt = ProfessionalSceneApplyReceipt(
        appliedCommandCount: 2,
        appliedCommandTypes: <String>[
          'applyTextLayer',
          'applyTimelineMutation'
        ],
        receivedRemoteLayers: 2,
        operationApplied: 'update',
        createdLayerCount: 0,
        updatedLayerCount: 2,
        targetLayerIds: <String>['layer.text.1'],
      );

      final proof = evaluator.buildSuccessProof(
        receipt: receipt,
        didApply: true,
        hasRepresentedRemoteLayer: true,
        proofFrameTimeMs: 1333,
        playerInvalidated: true,
      );

      expect(proof['dataApplied'], isTrue);
      expect(proof['localGraphApplied'], isTrue);
      expect(proof['timelineVisible'], isTrue);
      expect(proof['rendererApplied'], isTrue);
      expect(proof['targetLayerId'], 'layer.text.1');
      expect(proof['operationApplied'], 'update');
      expect(proof['proofFrameTimeMs'], 1333);
    });

    test('buildSuccessProof remains conservative when nothing was applied', () {
      const receipt = ProfessionalSceneApplyReceipt(
        appliedCommandCount: 0,
        appliedCommandTypes: <String>[],
        receivedRemoteLayers: 1,
      );

      final proof = evaluator.buildSuccessProof(
        receipt: receipt,
        didApply: false,
        hasRepresentedRemoteLayer: false,
        proofFrameTimeMs: 0,
        playerInvalidated: false,
      );

      expect(proof['dataApplied'], isFalse);
      expect(proof['rendererApplied'], isFalse);
      expect(proof['timelineVisible'], isFalse);
      expect(proof['playerInvalidated'], isFalse);
    });

    test('buildFailureProof returns hard fail proof contract', () {
      final proof = evaluator.buildFailureProof();
      expect(proof['dataApplied'], isFalse);
      expect(proof['localGraphApplied'], isFalse);
      expect(proof['timelineVisible'], isFalse);
      expect(proof['rendererApplied'], isFalse);
      expect(proof['visualBoundsVerified'], isFalse);
    });
  });
}
