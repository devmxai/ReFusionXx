import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/scene_semantic_blueprint_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_runtime_time_scope.dart';

void main() {
  const service = SceneRuntimeTimeScopeService();
  final beat = SemanticSceneBlueprintBeat(
    id: 'intro',
    startMs: 1000,
    endMs: 2000,
    intent: 'intro',
  );

  test('maps timeline time into clamped local beat time', () {
    final before = service.evaluateBeat(beat: beat, timelineTimeMs: 500);
    final start = service.evaluateBeat(beat: beat, timelineTimeMs: 1000);
    final middle = service.evaluateBeat(beat: beat, timelineTimeMs: 1500);
    final end = service.evaluateBeat(beat: beat, timelineTimeMs: 2000);
    final after = service.evaluateBeat(beat: beat, timelineTimeMs: 2400);

    expect(before.localTime, 0.0);
    expect(before.phase, SceneRuntimeBeatPhase.before);
    expect(start.localTime, 0.0);
    expect(start.phase, SceneRuntimeBeatPhase.enter);
    expect(middle.localTime, closeTo(0.5, 1e-6));
    expect(end.localTime, 1.0);
    expect(end.phase, SceneRuntimeBeatPhase.exit);
    expect(after.localTime, 1.0);
    expect(after.phase, SceneRuntimeBeatPhase.after);
  });

  test('normalizes invalid phase ratios safely', () {
    final scoped = service.evaluateBeat(
      beat: beat,
      timelineTimeMs: 1500,
      enterRatio: -2.0,
      holdRatio: double.nan,
      exitRatio: 0.0,
    );
    expect(scoped.enterBoundary, closeTo(0.25, 1e-6));
    expect(scoped.holdBoundary, closeTo(0.80, 1e-6));
    expect(scoped.phase, SceneRuntimeBeatPhase.hold);
  });

  test('marks active only inside beat window', () {
    final before = service.evaluateBeat(beat: beat, timelineTimeMs: 999);
    final atStart = service.evaluateBeat(beat: beat, timelineTimeMs: 1000);
    final atEnd = service.evaluateBeat(beat: beat, timelineTimeMs: 2000);
    final after = service.evaluateBeat(beat: beat, timelineTimeMs: 2001);

    expect(before.active, isFalse);
    expect(atStart.active, isTrue);
    expect(atEnd.active, isTrue);
    expect(after.active, isFalse);
  });
}
