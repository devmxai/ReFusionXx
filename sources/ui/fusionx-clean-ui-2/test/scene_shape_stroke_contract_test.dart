import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_shape_stroke_contract.dart';

void main() {
  const contract = SceneShapeStrokeContract();

  test('fails when prompt shell has effectively invisible stroke', () {
    final result = contract.evaluate(
      const SceneShapeStrokeContractRequest(
        elementId: 'prompt-shell',
        elementKind: 'shape',
        properties: <String, Object?>{
          'strokeWidth': 0.2,
        },
        scaleX: 1.0,
        scaleY: 1.0,
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      ),
      isTrue,
    );
  });

  test('passes when prompt shell has visible stroke', () {
    final result = contract.evaluate(
      const SceneShapeStrokeContractRequest(
        elementId: 'prompt-shell',
        elementKind: 'shape',
        properties: <String, Object?>{
          'strokeWidth': 1.2,
          'strokeAlign': 'inside',
        },
        scaleX: 1.0,
        scaleY: 1.0,
      ),
    );

    expect(result.isValid, isTrue);
    expect(result.effectiveStrokePx, greaterThanOrEqualTo(1.0));
    expect(
      result.issues.any(
        (issue) => issue.message.contains(SceneShapeStrokeContract.proofTag),
      ),
      isTrue,
    );
  });
}
