import '../models/scene_semantic_blueprint_models.dart';

enum SceneRuntimeBeatPhase {
  before,
  enter,
  hold,
  exit,
  after,
}

class SceneRuntimeBeatTimeScope {
  const SceneRuntimeBeatTimeScope({
    required this.beatId,
    required this.timelineTimeMs,
    required this.localTime,
    required this.phase,
    required this.active,
    required this.enterBoundary,
    required this.holdBoundary,
  });

  final String beatId;
  final int timelineTimeMs;
  final double localTime;
  final SceneRuntimeBeatPhase phase;
  final bool active;
  final double enterBoundary;
  final double holdBoundary;
}

class SceneRuntimeTimeScopeService {
  const SceneRuntimeTimeScopeService();

  SceneRuntimeBeatTimeScope evaluateBeat({
    required SemanticSceneBlueprintBeat beat,
    required int timelineTimeMs,
    double enterRatio = 0.25,
    double holdRatio = 0.55,
    double exitRatio = 0.20,
  }) {
    final boundaries = _resolveBoundaries(
      enterRatio: enterRatio,
      holdRatio: holdRatio,
      exitRatio: exitRatio,
    );
    final duration = (beat.endMs - beat.startMs).clamp(1, 1 << 30);
    final rawLocal = (timelineTimeMs - beat.startMs) / duration;
    final clamped = rawLocal.clamp(0.0, 1.0);
    final active =
        timelineTimeMs >= beat.startMs && timelineTimeMs <= beat.endMs;
    final phase = _phaseForLocalTime(
      localTime: clamped,
      rawLocalTime: rawLocal,
      enterBoundary: boundaries.enterBoundary,
      holdBoundary: boundaries.holdBoundary,
    );
    return SceneRuntimeBeatTimeScope(
      beatId: beat.id,
      timelineTimeMs: timelineTimeMs,
      localTime: clamped,
      phase: phase,
      active: active,
      enterBoundary: boundaries.enterBoundary,
      holdBoundary: boundaries.holdBoundary,
    );
  }

  SceneRuntimeBeatPhase _phaseForLocalTime({
    required double localTime,
    required double rawLocalTime,
    required double enterBoundary,
    required double holdBoundary,
  }) {
    if (rawLocalTime < 0.0) {
      return SceneRuntimeBeatPhase.before;
    }
    if (rawLocalTime > 1.0) {
      return SceneRuntimeBeatPhase.after;
    }
    if (localTime <= enterBoundary) {
      return SceneRuntimeBeatPhase.enter;
    }
    if (localTime <= holdBoundary) {
      return SceneRuntimeBeatPhase.hold;
    }
    return SceneRuntimeBeatPhase.exit;
  }

  ({double enterBoundary, double holdBoundary}) _resolveBoundaries({
    required double enterRatio,
    required double holdRatio,
    required double exitRatio,
  }) {
    final safeEnter = _safeRatio(enterRatio);
    final safeHold = _safeRatio(holdRatio);
    final safeExit = _safeRatio(exitRatio);
    final sum = safeEnter + safeHold + safeExit;
    if (sum <= 1e-6) {
      return (enterBoundary: 0.25, holdBoundary: 0.80);
    }
    final normalizedEnter = safeEnter / sum;
    final normalizedHold = safeHold / sum;
    final enterBoundary = normalizedEnter.clamp(0.0, 1.0);
    final holdBoundary =
        (enterBoundary + normalizedHold).clamp(enterBoundary, 1.0);
    return (enterBoundary: enterBoundary, holdBoundary: holdBoundary);
  }

  double _safeRatio(double value) {
    if (value.isNaN || !value.isFinite || value < 0.0) {
      return 0.0;
    }
    return value;
  }
}
