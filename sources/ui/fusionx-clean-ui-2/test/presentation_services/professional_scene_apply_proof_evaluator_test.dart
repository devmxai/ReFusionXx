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

    test(
      'buildSuccessProof marks renderer/timeline applied when execution succeeded '
      'even if representation hint is delayed',
      () {
        const receipt = ProfessionalSceneApplyReceipt(
          appliedCommandCount: 1,
          appliedCommandTypes: <String>['applyShapeLayer'],
          receivedRemoteLayers: 1,
          operationApplied: 'insert',
          createdLayerCount: 1,
          updatedLayerCount: 0,
        );

        final proof = evaluator.buildSuccessProof(
          receipt: receipt,
          didApply: true,
          hasRepresentedRemoteLayer: false,
          proofFrameTimeMs: 24,
          playerInvalidated: true,
        );

        expect(proof['dataApplied'], isTrue);
        expect(proof['timelineVisible'], isTrue);
        // Renderer proof now requires a resolved target (or explicit override).
        expect(proof['rendererApplied'], isFalse);
        expect(proof['visualBoundsVerified'], isTrue);
      },
    );

    test('buildSuccessProof accepts projection overrides and extra proof', () {
      const receipt = ProfessionalSceneApplyReceipt(
        appliedCommandCount: 1,
        appliedCommandTypes: <String>['applyShapeLayer'],
        receivedRemoteLayers: 1,
        targetLayerIds: <String>['remote-shape-1'],
      );
      final proof = evaluator.buildSuccessProof(
        receipt: receipt,
        didApply: true,
        hasRepresentedRemoteLayer: true,
        proofFrameTimeMs: 55,
        playerInvalidated: true,
        timelineVisibleOverride: false,
        rendererAppliedOverride: false,
        visualBoundsVerifiedOverride: false,
        extraProof: const <String, Object?>{
          'targetProjectionComplete': false,
          'projectedTargetCount': 0,
        },
      );

      expect(proof['timelineVisible'], isFalse);
      expect(proof['rendererApplied'], isFalse);
      expect(proof['visualBoundsVerified'], isFalse);
      expect(proof['targetProjectionComplete'], isFalse);
      expect(proof['projectedTargetCount'], 0);
    });

    test('buildSuccessProof allows independent visual bounds override', () {
      const receipt = ProfessionalSceneApplyReceipt(
        appliedCommandCount: 1,
        appliedCommandTypes: <String>['applySolidLayer'],
        receivedRemoteLayers: 1,
      );
      final proof = evaluator.buildSuccessProof(
        receipt: receipt,
        didApply: true,
        hasRepresentedRemoteLayer: true,
        proofFrameTimeMs: 99,
        playerInvalidated: true,
        rendererAppliedOverride: true,
        visualBoundsVerifiedOverride: false,
      );

      expect(proof['rendererApplied'], isTrue);
      expect(proof['visualBoundsVerified'], isFalse);
    });

    test('buildSuccessProof carries motion channel target proof', () {
      const receipt = ProfessionalSceneApplyReceipt(
        appliedCommandCount: 3,
        appliedCommandTypes: <String>['applyMotionChannel'],
        receivedRemoteLayers: 0,
        appliedMotionChannels: 3,
        lastAppliedMotionChannelsBatch: 3,
        operationApplied: 'motion',
        createdLayerCount: 0,
        updatedLayerCount: 1,
        targetLayerIds: <String>['remote-text-1'],
      );

      final proof = evaluator.buildSuccessProof(
        receipt: receipt,
        didApply: true,
        hasRepresentedRemoteLayer: true,
        proofFrameTimeMs: 120,
        playerInvalidated: true,
      );

      expect(proof['operationApplied'], 'motion');
      expect(proof['appliedMotionChannels'], 3);
      expect(proof['lastAppliedMotionChannelsBatch'], 3);
      expect(proof['targetLayerId'], 'remote-text-1');
      expect(proof['targetLayerIds'], <String>['remote-text-1']);
      expect(proof['updatedLayerCount'], 1);
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
