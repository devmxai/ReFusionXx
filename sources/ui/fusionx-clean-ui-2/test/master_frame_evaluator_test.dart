import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/creative_transaction_contract_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_frame_evaluator.dart';
import 'package:refusion_app/features/editor/domain/services/unified_creative_apply_engine.dart';

void main() {
  group('MasterFrameEvaluator', () {
    const evaluator = MasterFrameEvaluator();

    test('evaluates deterministic linear interpolation for motion channels', () {
      const layer = UnifiedCreativeLayerNode(
        identity: CreativeLayerIdentity(
          layerId: 'shape-1',
          kind: 'shape',
          compositionId: 'story-1',
          timelineTrackId: 'shape',
          zOrder: 0,
          createdBy: CreativeTransactionSource.manualUi,
          createdAtRevision: 1,
          updatedAtRevision: 1,
        ),
        x: 0,
        y: 0,
        width: 200,
        height: 200,
        motionChannels: <UnifiedCreativeMotionChannel>[
          UnifiedCreativeMotionChannel(
            channelId: 'shape-1.x',
            layerId: 'shape-1',
            propertyId: 'x',
            keyframes: <UnifiedCreativeKeyframe>[
              UnifiedCreativeKeyframe(timeMs: 0, value: 0),
              UnifiedCreativeKeyframe(timeMs: 1000, value: 100),
            ],
          ),
        ],
      );

      final frameA = evaluator.evaluateLayerAtTime(layer: layer, timeMs: 250);
      final frameB = evaluator.evaluateLayerAtTime(layer: layer, timeMs: 250);
      final frameMid = evaluator.evaluateLayerAtTime(layer: layer, timeMs: 500);

      expect(frameA.x, 25);
      expect(frameB.x, 25);
      expect(frameMid.x, 50);
      expect(frameA.x, frameB.x);
    });
  });
}
