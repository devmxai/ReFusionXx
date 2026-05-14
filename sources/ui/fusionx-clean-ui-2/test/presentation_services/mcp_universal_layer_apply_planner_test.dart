import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/services/mcp_universal_layer_apply_planner.dart';
import 'package:refusion_app/features/editor/presentation/services/mcp_universal_layer_identity.dart';

void main() {
  group('UniversalLayerRuntimeUpdatePlanner', () {
    const planner = UniversalLayerRuntimeUpdatePlanner();

    test('insert intent with missing target creates new layer', () {
      const resolution = UniversalLayerResolution(
        result: UniversalLayerResolutionResult.missingTarget,
        target: UniversalLayerTarget(
          canonicalTargetId: null,
          targetKind: UniversalLayerTargetKind.textElement,
          targetFamily: 'text',
          remoteLayerId: 'remote-1',
          targetLayerId: null,
          localLayerId: null,
          clipId: null,
          elementId: null,
          sourceId: null,
          aliases: <String>[],
          resolutionSource: 'none',
          confidence: 0,
          isAmbiguous: false,
          isMissing: true,
          blockers: <String>['TARGET_NOT_FOUND'],
          metadata: <String, Object?>{},
        ),
        candidates: <String>[],
      );
      final diagnostic = planner.plan(
        remoteLayerId: 'remote-1',
        payloadSignature: 'insert#1',
        layerCountBefore: 2,
        intent: UniversalLayerApplyIntent.insert,
        resolution: resolution,
        previousPayloadSignature: null,
      );
      expect(
        diagnostic.decision,
        UniversalLayerApplyDecisionType.insertNewLayer,
      );
      expect(diagnostic.layerCountAfter, 3);
    });

    test('update intent with missing target blocks fail closed', () {
      const resolution = UniversalLayerResolution(
        result: UniversalLayerResolutionResult.missingTarget,
        target: UniversalLayerTarget(
          canonicalTargetId: null,
          targetKind: UniversalLayerTargetKind.shapeElement,
          targetFamily: 'shape',
          remoteLayerId: 'remote-shape',
          targetLayerId: null,
          localLayerId: null,
          clipId: null,
          elementId: null,
          sourceId: null,
          aliases: <String>[],
          resolutionSource: 'none',
          confidence: 0,
          isAmbiguous: false,
          isMissing: true,
          blockers: <String>['TARGET_NOT_FOUND'],
          metadata: <String, Object?>{},
        ),
        candidates: <String>[],
      );
      final diagnostic = planner.plan(
        remoteLayerId: 'remote-shape',
        payloadSignature: 'update#shape',
        layerCountBefore: 5,
        intent: UniversalLayerApplyIntent.update,
        resolution: resolution,
        previousPayloadSignature: null,
      );
      expect(
        diagnostic.decision,
        UniversalLayerApplyDecisionType.blockUnresolvedUpdate,
      );
      expect(diagnostic.layerCountAfter, 5);
    });

    test('motion intent with resolved target applies motion to existing', () {
      const resolution = UniversalLayerResolution(
        result: UniversalLayerResolutionResult.resolvedSingle,
        target: UniversalLayerTarget(
          canonicalTargetId: 'layer-1',
          targetKind: UniversalLayerTargetKind.textElement,
          targetFamily: 'text',
          remoteLayerId: 'remote-text',
          targetLayerId: 'layer-1',
          localLayerId: 'layer-1',
          clipId: null,
          elementId: 'element-1',
          sourceId: null,
          aliases: <String>['layer-1'],
          resolutionSource: 'targetLayerId',
          confidence: 1,
          isAmbiguous: false,
          isMissing: false,
          blockers: <String>[],
          metadata: <String, Object?>{},
        ),
        candidates: <String>['layer-1'],
      );
      final diagnostic = planner.plan(
        remoteLayerId: 'remote-text',
        payloadSignature: 'motion#1',
        layerCountBefore: 1,
        intent: UniversalLayerApplyIntent.motionMutation,
        resolution: resolution,
        previousPayloadSignature: null,
      );
      expect(
        diagnostic.decision,
        UniversalLayerApplyDecisionType.applyMotionToExistingLayer,
      );
      expect(diagnostic.appliedMotion, isTrue);
      expect(diagnostic.layerCountAfter, 1);
    });

    test('duplicate payload signature is skipped on resolved target', () {
      const resolution = UniversalLayerResolution(
        result: UniversalLayerResolutionResult.resolvedSingle,
        target: UniversalLayerTarget(
          canonicalTargetId: 'layer-1',
          targetKind: UniversalLayerTargetKind.textElement,
          targetFamily: 'text',
          remoteLayerId: 'remote-text',
          targetLayerId: 'layer-1',
          localLayerId: 'layer-1',
          clipId: null,
          elementId: 'element-1',
          sourceId: null,
          aliases: <String>['layer-1'],
          resolutionSource: 'targetLayerId',
          confidence: 1,
          isAmbiguous: false,
          isMissing: false,
          blockers: <String>[],
          metadata: <String, Object?>{},
        ),
        candidates: <String>['layer-1'],
      );
      final diagnostic = planner.plan(
        remoteLayerId: 'remote-text',
        payloadSignature: 'same#signature',
        layerCountBefore: 1,
        intent: UniversalLayerApplyIntent.update,
        resolution: resolution,
        previousPayloadSignature: 'same#signature',
      );
      expect(
        diagnostic.decision,
        UniversalLayerApplyDecisionType.skipDuplicatePayload,
      );
    });
  });
}
