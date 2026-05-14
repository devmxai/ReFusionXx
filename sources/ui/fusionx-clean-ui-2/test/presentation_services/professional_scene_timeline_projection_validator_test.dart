import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_scene_command_models.dart';
import 'package:refusion_app/features/editor/presentation/services/professional_scene_timeline_projection_validator.dart';

void main() {
  group('ProfessionalSceneTimelineProjectionValidator', () {
    const validator = ProfessionalSceneTimelineProjectionValidator();

    test('marks complete projection when all targets are represented', () {
      const receipt = ProfessionalSceneApplyReceipt(
        appliedCommandCount: 1,
        appliedCommandTypes: <String>['applyShapeLayer'],
        receivedRemoteLayers: 1,
        targetLayerIds: <String>['remote-shape-1'],
      );
      final result = validator.validate(
        receipt: receipt,
        isRepresentedLocally: (targetLayerId) =>
            targetLayerId == 'remote-shape-1',
        didApply: true,
        hasRepresentedRemoteLayer: true,
      );
      expect(result.timelineVisible, isTrue);
      expect(result.targetProjectionComplete, isTrue);
      expect(result.projectedCount, 1);
      expect(result.missingTargetIds, isEmpty);
    });

    test('marks incomplete projection when any target is missing', () {
      const receipt = ProfessionalSceneApplyReceipt(
        appliedCommandCount: 2,
        appliedCommandTypes: <String>['applyTextLayer', 'applyShapeLayer'],
        receivedRemoteLayers: 2,
        targetLayerIds: <String>['remote-text-1', 'remote-shape-1'],
      );
      final result = validator.validate(
        receipt: receipt,
        isRepresentedLocally: (targetLayerId) =>
            targetLayerId == 'remote-text-1',
        didApply: true,
        hasRepresentedRemoteLayer: true,
      );
      expect(result.timelineVisible, isTrue);
      expect(result.targetProjectionComplete, isFalse);
      expect(result.projectedCount, 1);
      expect(result.missingTargetIds, <String>['remote-shape-1']);
    });

    test('falls back to apply/representation flags when no targets exist', () {
      const receipt = ProfessionalSceneApplyReceipt(
        appliedCommandCount: 1,
        appliedCommandTypes: <String>['applyLegacyAnimation'],
        receivedRemoteLayers: 1,
      );
      final result = validator.validate(
        receipt: receipt,
        isRepresentedLocally: (_) => false,
        didApply: true,
        hasRepresentedRemoteLayer: false,
      );
      expect(result.timelineVisible, isTrue);
      expect(result.targetProjectionComplete, isTrue);
      expect(result.targetCount, 0);
    });
  });
}
