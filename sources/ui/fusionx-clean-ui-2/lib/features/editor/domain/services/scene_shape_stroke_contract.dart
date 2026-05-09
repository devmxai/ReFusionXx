import 'dart:math' as math;

import '../models/refusion_scene_program_models.dart';

enum SceneShapeStrokeAlignment {
  inside,
  center,
  outside,
}

class SceneShapeStrokeContractRequest {
  const SceneShapeStrokeContractRequest({
    required this.elementId,
    required this.elementKind,
    required this.properties,
    required this.scaleX,
    required this.scaleY,
  });

  final String elementId;
  final String elementKind;
  final Map<String, Object?> properties;
  final double scaleX;
  final double scaleY;
}

class SceneShapeStrokeContractResult {
  const SceneShapeStrokeContractResult({
    required this.issues,
    required this.effectiveStrokePx,
    required this.requiresVisibleStroke,
  });

  final List<ReFusionSceneProgramIssue> issues;
  final double effectiveStrokePx;
  final bool requiresVisibleStroke;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneShapeStrokeContract {
  const SceneShapeStrokeContract();

  static const String proofTag = 'TF_SCENE_SHAPE_STROKE_PROOF';
  static const double minVisibleStrokePx = 1.0;

  SceneShapeStrokeContractResult evaluate(
      SceneShapeStrokeContractRequest request) {
    final issues = <ReFusionSceneProgramIssue>[];
    final normalizedKind = _normalize(request.elementKind);
    if (normalizedKind != 'shape') {
      return SceneShapeStrokeContractResult(
        issues: const <ReFusionSceneProgramIssue>[],
        effectiveStrokePx: 0.0,
        requiresVisibleStroke: false,
      );
    }
    final normalizedId = _normalize(request.elementId);
    final requiresVisibleStroke = _bool(request.properties['requiresBorder']) ??
        normalizedId.contains('promptshell') ||
            normalizedId.contains('inputbar') ||
            normalizedId.contains('card');

    final strokeWidth = _double(request.properties['strokeWidth']) ??
        _double(request.properties['borderWidth']) ??
        _double(request.properties['stroke']) ??
        0.0;
    final alignment = _alignmentFromProperties(request.properties);
    final averageScale = (request.scaleX.abs().clamp(0.0, 100.0) +
            request.scaleY.abs().clamp(0.0, 100.0)) /
        2.0;
    final normalizedScale = averageScale <= 0 ? 1.0 : averageScale;
    final effectiveStrokePx = strokeWidth * normalizedScale;

    if (requiresVisibleStroke && effectiveStrokePx < minVisibleStrokePx) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Shape `${request.elementId}` requires a visible border, '
              'but effective stroke is ${effectiveStrokePx.toStringAsFixed(2)}px '
              '(min ${minVisibleStrokePx.toStringAsFixed(2)}px).',
          path: 'elements.${request.elementId}.strokeWidth',
        ),
      );
    }
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$proofTag '
            'elementId=${request.elementId} '
            'alignment=${alignment.name} '
            'strokeWidth=${strokeWidth.toStringAsFixed(2)} '
            'effectiveStrokePx=${effectiveStrokePx.toStringAsFixed(2)} '
            'requiresVisibleStroke=${requiresVisibleStroke.toString()}',
        path: 'elements.${request.elementId}.strokeWidth',
      ),
    );
    return SceneShapeStrokeContractResult(
      issues: List.unmodifiable(issues),
      effectiveStrokePx: effectiveStrokePx,
      requiresVisibleStroke: requiresVisibleStroke,
    );
  }

  SceneShapeStrokeAlignment _alignmentFromProperties(
      Map<String, Object?> properties) {
    final raw = (_string(properties['strokeAlign']) ??
            _string(properties['strokeAlignment']) ??
            _string(properties['borderAlign']) ??
            'center')
        .trim()
        .toLowerCase();
    switch (raw) {
      case 'inside':
        return SceneShapeStrokeAlignment.inside;
      case 'outside':
        return SceneShapeStrokeAlignment.outside;
      default:
        return SceneShapeStrokeAlignment.center;
    }
  }

  double? _double(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  bool? _bool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final raw = value.trim().toLowerCase();
      if (raw == 'true') {
        return true;
      }
      if (raw == 'false') {
        return false;
      }
    }
    return null;
  }

  String? _string(Object? value) {
    if (value is String) {
      return value;
    }
    return null;
  }

  String _normalize(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '').toLowerCase();
}
