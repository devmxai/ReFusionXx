import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_normal_transition_models.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_authoring_service.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_catalog.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  final definition =
      const NormalTransitionCatalog().loadBuiltIns().definitionById(
            'cross_dissolve',
          )!;
  const service = NormalTransitionAuthoringService();

  test('creates editable node and instance from cross dissolve definition', () {
    final result = service.createFromDefinition(
      NormalTransitionApplyRequest(
        definition: definition,
        trackId: 'video-main',
        leftClipId: 'clip-a',
        rightClipId: 'clip-b',
        boundaryTime: TimelineTime.fromMilliseconds(5000),
        leftAvailableTail: TimelineTime.fromMilliseconds(500),
        rightAvailableHead: TimelineTime.fromMilliseconds(500),
        parameterOverrides: const <String, Object>{
          'softness': 0.75,
        },
      ),
    );

    expect(result.canApply, isTrue);
    expect(result.issues, isEmpty);
    expect(result.node!.definitionId, 'cross_dissolve');
    expect(result.node!.parameterValues['softness'], 0.75);
    expect(result.node!.instanceId, result.instance!.id);
    expect(result.instance!.channels, hasLength(2));
    expect(
        result.instance!.sourceKind, NormalTransitionSourceKind.builtInPreset);
    expect(result.window!.start.inMilliseconds, 4640);
    expect(result.window!.endExclusive.inMilliseconds, 5360);
  });

  test('rejects duration outside definition limits', () {
    final result = service.createFromDefinition(
      NormalTransitionApplyRequest(
        definition: definition,
        trackId: 'video-main',
        leftClipId: 'clip-a',
        rightClipId: 'clip-b',
        boundaryTime: TimelineTime.fromMilliseconds(5000),
        leftAvailableTail: TimelineTime.fromMilliseconds(500),
        rightAvailableHead: TimelineTime.fromMilliseconds(500),
        duration: TimelineTime.fromMilliseconds(80),
      ),
    );

    expect(result.canApply, isFalse);
    expect(result.node, isNull);
    expect(result.instance, isNull);
    expect(result.issues.any((issue) => issue.path == 'duration'), isTrue);
  });

  test('rejects unknown and out-of-range parameter overrides', () {
    final result = service.createFromDefinition(
      NormalTransitionApplyRequest(
        definition: definition,
        trackId: 'video-main',
        leftClipId: 'clip-a',
        rightClipId: 'clip-b',
        boundaryTime: TimelineTime.fromMilliseconds(5000),
        leftAvailableTail: TimelineTime.fromMilliseconds(500),
        rightAvailableHead: TimelineTime.fromMilliseconds(500),
        parameterOverrides: const <String, Object>{
          'softness': 2.0,
          'mystery': 0.4,
        },
      ),
    );

    expect(result.canApply, isFalse);
    expect(result.node, isNull);
    expect(result.instance, isNull);
    expect(result.issues.map((issue) => issue.path),
        contains('parameters.softness'));
    expect(result.issues.map((issue) => issue.path),
        contains('parameters.mystery'));
  });

  test('blocks apply when transition handles are insufficient', () {
    final result = service.createFromDefinition(
      NormalTransitionApplyRequest(
        definition: definition,
        trackId: 'video-main',
        leftClipId: 'clip-a',
        rightClipId: 'clip-b',
        boundaryTime: TimelineTime.fromMilliseconds(5000),
        leftAvailableTail: TimelineTime.fromMilliseconds(359),
        rightAvailableHead: TimelineTime.fromMilliseconds(360),
      ),
    );

    expect(result.canApply, isFalse);
    expect(result.node, isNull);
    expect(result.instance, isNull);
    expect(result.window, isNotNull);
    expect(result.issues.single.path, 'leftClipId');
  });
}
