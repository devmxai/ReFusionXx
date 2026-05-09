import '../models/refusion_scene_program_models.dart';

enum SceneSlotLayoutPrimitive {
  fixed,
  fill,
  hug,
  stackHorizontal,
  stackVertical,
  grid,
  overlay,
  center,
  safeAreaInset,
}

class SceneSlotLayoutRect {
  const SceneSlotLayoutRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  SceneSlotLayoutRect inset({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    return SceneSlotLayoutRect(
      left: this.left + left,
      top: this.top + top,
      right: this.right - right,
      bottom: this.bottom - bottom,
    );
  }

  @override
  String toString() {
    return '${this.left.toStringAsFixed(2)},${this.top.toStringAsFixed(2)},'
        '${right.toStringAsFixed(2)},${bottom.toStringAsFixed(2)}';
  }
}

class SceneSlotLayoutIssue {
  const SceneSlotLayoutIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.path,
  });

  final ReFusionSceneProgramIssueSeverity severity;
  final String code;
  final String message;
  final String? path;
}

class SceneSlotLayoutSolveResult {
  const SceneSlotLayoutSolveResult({
    required this.slotBoundsByNodeId,
    required this.contentBoundsByComponentNodeId,
    required this.issues,
    required this.deterministicLayoutHash,
  });

  final Map<String, SceneSlotLayoutRect> slotBoundsByNodeId;
  final Map<String, SceneSlotLayoutRect> contentBoundsByComponentNodeId;
  final List<SceneSlotLayoutIssue> issues;
  final String deterministicLayoutHash;
}
