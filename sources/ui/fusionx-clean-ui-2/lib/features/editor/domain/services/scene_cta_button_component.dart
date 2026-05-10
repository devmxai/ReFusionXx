import 'dart:math' as math;

import '../models/refusion_scene_program_models.dart';

class SceneCtaButtonComponentValidationResult {
  SceneCtaButtonComponentValidationResult({
    required List<ReFusionSceneProgramIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneCtaButtonComponentValidator {
  const SceneCtaButtonComponentValidator();

  static const String proofTag = 'TF_SCENE_CTA_BUTTON_PROOF';
  static const String lifecycleProofTag = 'TF_SCENE_CTA_BUTTON_LIFECYCLE_PROOF';

  SceneCtaButtonComponentValidationResult validate(
    ReFusionSceneProgram program,
  ) {
    final entries = <_ProgramElementEntry>[];
    for (var layerIndex = 0; layerIndex < program.layers.length; layerIndex++) {
      final layer = program.layers[layerIndex];
      for (var elementIndex = 0;
          elementIndex < layer.elements.length;
          elementIndex++) {
        entries.add(
          _ProgramElementEntry(
            layerIndex: layerIndex,
            elementIndex: elementIndex,
            layer: layer,
            element: layer.elements[elementIndex],
          ),
        );
      }
    }

    final issues = <ReFusionSceneProgramIssue>[];
    final shells = entries.where(_isCtaShell).toList(growable: false);
    for (final shell in shells) {
      _validateShell(shell: shell, entries: entries, issues: issues);
    }
    return SceneCtaButtonComponentValidationResult(issues: issues);
  }

  bool _isCtaShell(_ProgramElementEntry entry) {
    if (_normalize(entry.element.kind) != 'shape') {
      return false;
    }
    final id = _normalize(entry.element.id);
    final componentType = _normalize(
      _stringFromMap(
            entry.element.properties,
            const <String>['componentType', 'component', 'semanticType'],
          ) ??
          '',
    );
    if (componentType == 'ctabutton') {
      return true;
    }
    return id.contains('ctabuttonshell');
  }

  void _validateShell({
    required _ProgramElementEntry shell,
    required List<_ProgramElementEntry> entries,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final shellPath =
        'layers[${shell.layerIndex}].elements[${shell.elementIndex}]';
    final shellRect = _rectFor(shell.element);
    final shellWindow = _windowFor(shell.layer);
    if (shellRect == null) {
      return;
    }

    final labelEntry = _findFirstEntry(
      entries,
      kind: 'text',
      parentId: shell.element.id,
    );
    final iconEntry = _findFirstEntry(
      entries,
      kind: 'icon',
      parentId: shell.element.id,
    );

    if (labelEntry == null || iconEntry == null) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'CTA_LABEL_OVERFLOW CTAButton `${shell.element.id}` must include parented label and trailing icon.',
          path: shellPath,
        ),
      );
      return;
    }

    final labelFrame = _mapFromMap(
      labelEntry.element.properties,
      const <String>['textFrame'],
    );
    if (labelFrame == null) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'CTA_LABEL_OVERFLOW Label `${labelEntry.element.id}` must define textFrame.',
          path:
              'layers[${labelEntry.layerIndex}].elements[${labelEntry.elementIndex}].properties.textFrame',
        ),
      );
    } else {
      final fitPolicy = _normalize(
        _stringFromMap(labelFrame, const <String>['fitPolicy']) ?? '',
      );
      if (fitPolicy != 'shrinktofit') {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'CTA_LABEL_OVERFLOW Label `${labelEntry.element.id}` must use `fitPolicy: shrinkToFit`.',
            path:
                'layers[${labelEntry.layerIndex}].elements[${labelEntry.elementIndex}].properties.textFrame.fitPolicy',
          ),
        );
      }
      final frameWidth = _doubleFromMap(labelFrame, const <String>['width']);
      final fontSize = _doubleFromMap(
            labelEntry.element.properties,
            const <String>['fontSize'],
          ) ??
          16;
      if (frameWidth != null) {
        final estimated = _estimateTextWidth(labelEntry.element, fontSize);
        if (estimated > frameWidth + 1.0) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message:
                  'CTA_LABEL_OVERFLOW Label `${labelEntry.element.id}` estimated width exceeds textFrame width.',
              path:
                  'layers[${labelEntry.layerIndex}].elements[${labelEntry.elementIndex}].properties.textFrame.width',
            ),
          );
        }
      }
    }

    final labelRect = _rectFor(labelEntry.element);
    final iconRect = _rectFor(iconEntry.element);
    if (labelRect != null && iconRect != null) {
      final labelBaseline = _labelBaselineY(labelEntry.element, labelRect);
      final iconBaseline = iconRect.centerY;
      final baselineDelta = (labelBaseline - iconBaseline).abs();
      final fontSize = _doubleFromMap(
            labelEntry.element.properties,
            const <String>['fontSize'],
          ) ??
          16;
      final allowedBaselineDelta = math.max(6.0, fontSize * 0.22);
      if (baselineDelta > allowedBaselineDelta) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'CTA_ICON_BASELINE_DRIFT Trailing icon `${iconEntry.element.id}` drifts from label baseline.',
            path:
                'layers[${iconEntry.layerIndex}].elements[${iconEntry.elementIndex}]',
          ),
        );
      }

      final groupLeft = math.min(labelRect.left, iconRect.left);
      final groupRight = math.max(labelRect.right, iconRect.right);
      final groupCenter = (groupLeft + groupRight) / 2.0;
      final centerDelta = (groupCenter - shellRect.centerX).abs();
      final allowedCenterDelta = math.max(8.0, shellRect.width * 0.06);
      if (centerDelta > allowedCenterDelta) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'CTA_ICON_BASELINE_DRIFT CTA label/icon group is not optically centered inside `${shell.element.id}`.',
            path: shellPath,
          ),
        );
      }
    }

    _validateLifecycle(
      shell: shell,
      shellWindow: shellWindow,
      child: labelEntry,
      issues: issues,
    );
    _validateLifecycle(
      shell: shell,
      shellWindow: shellWindow,
      child: iconEntry,
      issues: issues,
    );

    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$proofTag '
            'shell=${shell.element.id} '
            'label=${labelEntry.element.id} '
            'icon=${iconEntry.element.id}',
        path: shellPath,
      ),
    );
  }

  void _validateLifecycle({
    required _ProgramElementEntry shell,
    required _TimeWindow shellWindow,
    required _ProgramElementEntry child,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final childWindow = _windowFor(child.layer);
    final inside = childWindow.startMs >= shellWindow.startMs &&
        childWindow.endMs <= shellWindow.endMs;
    issues.add(
      ReFusionSceneProgramIssue(
        severity: inside
            ? ReFusionSceneProgramIssueSeverity.info
            : ReFusionSceneProgramIssueSeverity.error,
        message: '${inside ? lifecycleProofTag : 'CTA_CHILD_OUTLIVES_SHELL'} '
            'shell=${shell.element.id} '
            'child=${child.element.id} '
            'shellRange=${shellWindow.startMs}-${shellWindow.endMs} '
            'childRange=${childWindow.startMs}-${childWindow.endMs} '
            'insideShell=${inside.toString()}',
        path: 'layers[${child.layerIndex}].elements[${child.elementIndex}]',
      ),
    );
  }

  bool _isParentedTo(ReFusionSceneProgramElement element, String parentId) {
    final resolvedParent = _stringFromMap(
      element.properties,
      const <String>['parentId', 'parent', 'containerId', 'parentGroup'],
    );
    return resolvedParent == parentId;
  }

  _ProgramElementEntry? _findFirstEntry(
    List<_ProgramElementEntry> entries, {
    required String kind,
    required String parentId,
  }) {
    final normalizedKind = _normalize(kind);
    for (final entry in entries) {
      if (_normalize(entry.element.kind) != normalizedKind) {
        continue;
      }
      if (_isParentedTo(entry.element, parentId)) {
        return entry;
      }
    }
    return null;
  }

  _RectLike? _rectFor(ReFusionSceneProgramElement element) {
    final position = element.properties['position'];
    if (position is! Map<String, Object?>) {
      return null;
    }
    final x = _doubleFromMap(position, const <String>['x']);
    final y = _doubleFromMap(position, const <String>['y']);
    var width = _doubleFromMap(element.properties, const <String>['width']);
    var height = _doubleFromMap(element.properties, const <String>['height']);
    if ((width == null || height == null) &&
        _normalize(element.kind) == 'text') {
      final textFrame = _mapFromMap(
        element.properties,
        const <String>['textFrame'],
      );
      if (textFrame != null) {
        width ??= _doubleFromMap(textFrame, const <String>['width']);
        height ??= _doubleFromMap(textFrame, const <String>['height']);
      }
    }
    if (x == null || y == null || width == null || height == null) {
      return null;
    }
    return _RectLike.fromCenter(
      centerX: x,
      centerY: y,
      width: width,
      height: height,
    );
  }

  _TimeWindow _windowFor(ReFusionSceneProgramLayer layer) {
    return _TimeWindow(
      startMs: layer.startMs,
      endMs: layer.startMs + layer.durationMs,
    );
  }

  double _labelBaselineY(
    ReFusionSceneProgramElement label,
    _RectLike rect,
  ) {
    final fontSize =
        _doubleFromMap(label.properties, const <String>['fontSize']);
    if (fontSize == null) {
      return rect.centerY;
    }
    final lineHeight =
        _doubleFromMap(label.properties, const <String>['lineHeight']) ?? 1;
    final baselineOffset = fontSize * lineHeight * 0.12;
    return rect.centerY + baselineOffset;
  }

  double _estimateTextWidth(
      ReFusionSceneProgramElement element, double fontSize) {
    final text = element.text ?? '';
    final letterSpacing = _doubleFromMap(
          element.properties,
          const <String>['letterSpacing'],
        ) ??
        0;
    final base = text.length * fontSize * 0.50;
    final tracking = math.max(0, text.length - 1) * letterSpacing;
    return base + tracking;
  }

  Map<String, Object?>? _mapFromMap(
      Map<String, Object?> source, List<String> keys) {
    final value = _valueFromMap(source, keys);
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, Object?>();
    }
    return null;
  }

  String? _stringFromMap(Map<String, Object?> source, List<String> keys) {
    final value = _valueFromMap(source, keys);
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _doubleFromMap(Map<String, Object?> source, List<String> keys) {
    final value = _valueFromMap(source, keys);
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  Object? _valueFromMap(Map<String, Object?> source, List<String> keys) {
    final normalizedKeys = keys.map(_normalize).toSet();
    for (final entry in source.entries) {
      if (normalizedKeys.contains(_normalize(entry.key))) {
        return entry.value;
      }
    }
    return null;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}

class _ProgramElementEntry {
  const _ProgramElementEntry({
    required this.layerIndex,
    required this.elementIndex,
    required this.layer,
    required this.element,
  });

  final int layerIndex;
  final int elementIndex;
  final ReFusionSceneProgramLayer layer;
  final ReFusionSceneProgramElement element;
}

class _TimeWindow {
  const _TimeWindow({
    required this.startMs,
    required this.endMs,
  });

  final int startMs;
  final int endMs;
}

class _RectLike {
  const _RectLike({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory _RectLike.fromCenter({
    required double centerX,
    required double centerY,
    required double width,
    required double height,
  }) {
    return _RectLike(
      left: centerX - width / 2.0,
      top: centerY - height / 2.0,
      right: centerX + width / 2.0,
      bottom: centerY + height / 2.0,
    );
  }

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get centerX => (left + right) / 2.0;
  double get centerY => (top + bottom) / 2.0;
}
