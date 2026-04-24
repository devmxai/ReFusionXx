import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_normal_transition_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  test('normal transition overlap is derived from boundary without mutation',
      () {
    final node = NormalTransitionNode(
      id: 'transition-1',
      trackId: 'video-main',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      definitionId: 'cross_dissolve',
      duration: TimelineTime.fromMilliseconds(800),
    );

    final window = node.resolveOverlap(
      boundaryTime: TimelineTime.fromMilliseconds(5000),
    );

    expect(window.start.inMilliseconds, 4600);
    expect(window.boundaryTime.inMilliseconds, 5000);
    expect(window.endExclusive.inMilliseconds, 5400);
    expect(window.leadingDuration.inMilliseconds, 400);
    expect(window.trailingDuration.inMilliseconds, 400);
    expect(window.progressAt(TimelineTime.fromMilliseconds(5000)), 0.5);
    expect(window.contains(TimelineTime.fromMilliseconds(5399)), isTrue);
    expect(window.contains(TimelineTime.fromMilliseconds(5400)), isFalse);
  });

  test('handle validation rejects insufficient source handles', () {
    final node = NormalTransitionNode(
      id: 'transition-1',
      trackId: 'video-main',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      definitionId: 'cross_dissolve',
      duration: TimelineTime.fromMilliseconds(800),
    );

    final result = node.validateHandles(
      boundaryTime: TimelineTime.fromMilliseconds(5000),
      leftAvailableTail: TimelineTime.fromMilliseconds(399),
      rightAvailableHead: TimelineTime.fromMilliseconds(400),
    );

    expect(result.isValid, isFalse);
    expect(result.issues, hasLength(1));
    expect(result.issues.single.path, 'leftClipId');
  });

  test('transition definition exposes immutable default parameter values', () {
    final definition = NormalTransitionDefinition(
      definitionId: 'cross_dissolve',
      schemaVersion: kNormalTransitionSchemaVersion,
      label: 'Cross Dissolve',
      category: NormalTransitionCategory.basic,
      rendererTier: NormalTransitionRendererTier.primitive,
      defaultDuration: TimelineTime.fromMilliseconds(600),
      parameters: <NormalTransitionParameterSchema>[
        NormalTransitionParameterSchema(
          name: 'softness',
          type: NormalTransitionParameterType.number,
          defaultValue: 0.5,
          range: const NormalTransitionNumberRange(min: 0, max: 1),
        ),
      ],
    );

    expect(definition.defaultParameterValues['softness'], 0.5);
    expect(
      () => definition.defaultParameterValues['softness'] = 0.7,
      throwsUnsupportedError,
    );
  });
}
