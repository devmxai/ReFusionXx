import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/services/mcp_text_layer_resolution.dart';
import 'package:refusion_app/features/editor/presentation/services/mcp_text_runtime_update_planner.dart';

void main() {
  group('PNCLE-05B.RUNTIME-TEXT-UPDATE-E2E-HARDENING', () {
    const planner = McpTextRuntimeUpdatePlanner();
    const motionPlanner = McpTextMotionTargetPlanner();

    test('Test 1: insert text without target creates new text', () {
      final updateIntent = McpTextLayerResolution.requestsUpdate(
        payload: const <String, Object?>{
          'operation': 'insert_layer',
        },
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
      );
      final block = McpTextLayerResolution.shouldBlockInsert(
        updateIntent: updateIntent,
        resolvedLayerId: null,
        resolvedTargetIsTextElement: false,
      );
      final diagnostic = planner.plan(
        remoteLayerId: 'remote-text-1',
        payloadSignature: 'insert#remote-text-1',
        textElementCountBefore: 0,
        updateIntent: updateIntent,
        blockInsert: block,
        hasResolvedTextTarget: false,
        resolvedLayerId: null,
        resolvedElementId: null,
        previousPayloadSignature: null,
      );
      expect(diagnostic.createdNewText, isTrue);
      expect(diagnostic.updatedExistingText, isFalse);
      expect(diagnostic.textElementCountAfter, 1);
    });

    test('Test 2: update same remoteLayerId keeps text count stable', () {
      final updateIntent = McpTextLayerResolution.requestsUpdate(
        payload: const <String, Object?>{
          'operation': 'update_layer',
          'targetLayerId': 'remote-text-1',
        },
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
      );
      final block = McpTextLayerResolution.shouldBlockInsert(
        updateIntent: updateIntent,
        resolvedLayerId: 'layer-text-1',
        resolvedTargetIsTextElement: true,
      );
      final diagnostic = planner.plan(
        remoteLayerId: 'remote-text-1',
        payloadSignature: 'update#remote-text-1#v2',
        textElementCountBefore: 1,
        updateIntent: updateIntent,
        blockInsert: block,
        hasResolvedTextTarget: true,
        resolvedLayerId: 'layer-text-1',
        resolvedElementId: 'element-text-1',
        previousPayloadSignature: 'insert#remote-text-1',
      );
      expect(diagnostic.createdNewText, isFalse);
      expect(diagnostic.updatedExistingText, isTrue);
      expect(diagnostic.textElementCountAfter, 1);
      expect(diagnostic.resolvedElementId, 'element-text-1');
    });

    test('Test 3: update via different command id targets existing text', () {
      final resolved = McpTextLayerResolution.resolveCandidateLayerId(
        remoteLayerId: 'update-command-2',
        payload: const <String, Object?>{
          'targetLayerId': 'remote-text-1',
        },
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
        exists: (layerId) => layerId == 'remote-text-1',
      );
      expect(resolved, 'remote-text-1');
    });

    test('Test 4: unresolved update target is blocked fail-closed', () {
      final updateIntent = McpTextLayerResolution.requestsUpdate(
        payload: const <String, Object?>{
          'operation': 'update_text',
          'targetLayerId': 'missing-text',
        },
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
      );
      final block = McpTextLayerResolution.shouldBlockInsert(
        updateIntent: updateIntent,
        resolvedLayerId: null,
        resolvedTargetIsTextElement: false,
      );
      final diagnostic = planner.plan(
        remoteLayerId: 'missing-text',
        payloadSignature: 'update#missing-text',
        textElementCountBefore: 2,
        updateIntent: updateIntent,
        blockInsert: block,
        hasResolvedTextTarget: false,
        resolvedLayerId: null,
        resolvedElementId: null,
        previousPayloadSignature: null,
      );
      expect(diagnostic.blockedUnresolvedUpdate, isTrue);
      expect(diagnostic.createdNewText, isFalse);
      expect(diagnostic.textElementCountAfter, 2);
    });

    test('Test 5: suspicious insert with target id is treated as update intent',
        () {
      final updateIntent = McpTextLayerResolution.requestsUpdate(
        payload: const <String, Object?>{
          'operation': 'insert_layer',
          'targetLayerId': 'remote-text-1',
        },
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
      );
      expect(updateIntent, isTrue);
    });

    test('Test 6: motion after update keeps same text target identity', () {
      final motionDecision = motionPlanner.decide(
        hasElementContext: true,
        isTextLayerHint: true,
        hasFallbackClip: true,
      );
      expect(motionDecision, McpTextMotionTargetDecision.element);

      final blockedDecision = motionPlanner.decide(
        hasElementContext: false,
        isTextLayerHint: true,
        hasFallbackClip: true,
      );
      expect(
        blockedDecision,
        McpTextMotionTargetDecision.blockedUnresolvedTextTarget,
      );
    });

    test('Test 7: ambiguous update without resolvable ids is blocked', () {
      final updateIntent = McpTextLayerResolution.requestsUpdate(
        payload: const <String, Object?>{
          'operation': 'set_text_style',
        },
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
      );
      final block = McpTextLayerResolution.shouldBlockInsert(
        updateIntent: updateIntent,
        resolvedLayerId: null,
        resolvedTargetIsTextElement: false,
      );
      final diagnostic = planner.plan(
        remoteLayerId: 'ambiguous-command',
        payloadSignature: 'set_text_style#ambiguous',
        textElementCountBefore: 2,
        updateIntent: updateIntent,
        blockInsert: block,
        hasResolvedTextTarget: false,
        resolvedLayerId: null,
        resolvedElementId: null,
        previousPayloadSignature: null,
      );
      expect(diagnostic.blockedUnresolvedUpdate, isTrue);
      expect(diagnostic.createdNewText, isFalse);
    });

    test('duplicate payload signature short-circuits duplicate apply', () {
      final diagnostic = planner.plan(
        remoteLayerId: 'remote-text-1',
        payloadSignature: 'update#remote-text-1#v2',
        textElementCountBefore: 1,
        updateIntent: true,
        blockInsert: false,
        hasResolvedTextTarget: true,
        resolvedLayerId: 'layer-text-1',
        resolvedElementId: 'element-text-1',
        previousPayloadSignature: 'update#remote-text-1#v2',
      );
      expect(diagnostic.skippedDuplicateApply, isTrue);
      expect(diagnostic.textElementCountAfter, 1);
    });
  });
}
