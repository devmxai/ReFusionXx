import 'dart:math' as math;

import '../models/refusion_scene_program_models.dart';
import 'scene_prompt_input_bar_component.dart';

class SceneProgramComponentContractResult {
  SceneProgramComponentContractResult({
    required List<ReFusionSceneProgramIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneProgramComponentContractValidator {
  const SceneProgramComponentContractValidator({
    ScenePromptInputBarComponentValidator promptInputBarValidator =
        const ScenePromptInputBarComponentValidator(),
  }) : _promptInputBarValidator = promptInputBarValidator;

  final ScenePromptInputBarComponentValidator _promptInputBarValidator;

  SceneProgramComponentContractResult validate(ReFusionSceneProgram program) {
    final issues = <ReFusionSceneProgramIssue>[];
    for (var layerIndex = 0; layerIndex < program.layers.length; layerIndex++) {
      final layer = program.layers[layerIndex];
      _lintPromptInputBarContract(
        layer: layer,
        layerIndex: layerIndex,
        issues: issues,
      );
    }
    final promptInputBarResult = _promptInputBarValidator.validate(program);
    issues.addAll(promptInputBarResult.issues);
    return SceneProgramComponentContractResult(issues: issues);
  }

  void _lintPromptInputBarContract({
    required ReFusionSceneProgramLayer layer,
    required int layerIndex,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final elements = layer.elements;
    if (elements.isEmpty) {
      return;
    }
    final shellEntry = _findElement(
      elements,
      byContains: 'promptshell',
    );
    final textEntry = _findElement(
      elements,
      byContains: 'prompttext',
      kind: 'text',
    );
    final sendButtonEntry = _findElement(
      elements,
      byContains: 'sendbutton',
    );

    final looksLikePromptInputBar =
        shellEntry != null && textEntry != null && sendButtonEntry != null;
    if (!looksLikePromptInputBar) {
      return;
    }

    final shell = shellEntry!.element;
    final text = textEntry!.element;
    final shellPath = 'layers[$layerIndex].elements[${shellEntry.index}]';
    final textPath = 'layers[$layerIndex].elements[${textEntry.index}]';

    final shellRole = _stringFromProperties(
          shell.properties,
          const <String>['layoutRole', 'role'],
        ) ??
        _stringFromMap(
          _mapFromProperties(shell.properties, const <String>['layout']),
          const <String>['layoutRole', 'role'],
        );
    final normalizedShellRole = _normalizeToken(shellRole ?? '');
    if (normalizedShellRole != 'container' && normalizedShellRole != 'group') {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'PromptInputBar requires prompt shell `${shell.id}` to declare `layoutRole: "container"`.',
          path: '$shellPath.properties.layoutRole',
        ),
      );
    }

    final parentId = _stringFromProperties(
          text.properties,
          const <String>['parentId', 'parent', 'containerId', 'parentGroup'],
        ) ??
        _stringFromMap(
          _mapFromProperties(text.properties, const <String>['layout']),
          const <String>['parentId', 'parent', 'containerId'],
        );
    if (parentId != shell.id) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'PromptInputBar text `${text.id}` must set `parentId` to `${shell.id}`.',
          path: '$textPath.properties.parentId',
        ),
      );
    }

    final textFrame = _mapFromProperties(
      text.properties,
      const <String>['textFrame', 'layoutTextFrame'],
    );
    if (textFrame == null) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'PromptInputBar text `${text.id}` must declare a `textFrame` contract.',
          path: '$textPath.properties.textFrame',
        ),
      );
      return;
    }

    final maxLines = _doubleFromMap(textFrame, const <String>['maxLines']);
    if (maxLines == null || maxLines < 1 || maxLines > 1.5) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'PromptInputBar text `${text.id}` must enforce one line (`textFrame.maxLines = 1`).',
          path: '$textPath.properties.textFrame.maxLines',
        ),
      );
    }

    final overflow = _stringFromMap(
      textFrame,
      const <String>['overflow', 'overflowPolicy'],
    );
    final normalizedOverflow = _normalizeToken(overflow ?? '');
    if (normalizedOverflow.isEmpty) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.warning,
          message:
              'PromptInputBar text `${text.id}` should declare `textFrame.overflow` (`error`, `clip`, or `ellipsis`).',
          path: '$textPath.properties.textFrame.overflow',
        ),
      );
    }

    final shellRect = _rectForElement(shell);
    final textPosition = _pointFromProperties(text.properties);
    if (shellRect == null || textPosition == null) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.warning,
          message:
              'TF_SCENE_LAYOUT_GEOMETRY_PROOF fallbackReason=missing_shell_or_text_position shell=${shell.id} text=${text.id}',
          path: textPath,
        ),
      );
      return;
    }

    final insets = _insetsForShell(shell.properties);
    final contentLeft = shellRect.left + insets.left;
    final contentRight = shellRect.right - insets.right;
    final contentTop = shellRect.top + insets.top;
    final contentBottom = shellRect.bottom - insets.bottom;
    final contentWidth = math.max(0.0, contentRight - contentLeft);
    final contentHeight = math.max(0.0, contentBottom - contentTop);

    final estimatedTextWidth = _estimateTextWidth(text);
    final estimatedTextHeight = _estimateTextHeight(text);
    final textRect = _RectLike(
      left: textPosition.dx - (estimatedTextWidth / 2),
      top: textPosition.dy - (estimatedTextHeight / 2),
      right: textPosition.dx + (estimatedTextWidth / 2),
      bottom: textPosition.dy + (estimatedTextHeight / 2),
    );

    final fitsHorizontally = textRect.left >= contentLeft - 1.0 &&
        textRect.right <= contentRight + 1.0;
    final fitsVertically = textRect.top >= contentTop - 1.0 &&
        textRect.bottom <= contentBottom + 1.0;
    final hasTextOverflow = !(fitsHorizontally && fitsVertically);

    final textFrameWidth =
        _doubleFromMap(textFrame, const <String>['width', 'maxWidth']);
    if (textFrameWidth != null && textFrameWidth > contentWidth + 1.0) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'PromptInputBar textFrame width exceeds shell content width for `${text.id}`.',
          path: '$textPath.properties.textFrame.width',
        ),
      );
    }

    if (hasTextOverflow) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'PromptInputBar text `${text.id}` overflows shell content rect. Keep text within safe padding and trailing accessory reserve.',
          path: textPath,
        ),
      );
    }

    final proofMessage = StringBuffer()
      ..write('TF_SCENE_LAYOUT_GEOMETRY_PROOF ')
      ..write('layer=${layer.id} ')
      ..write('shell=${shell.id} ')
      ..write('text=${text.id} ')
      ..write(
        'contentRect=${contentLeft.toStringAsFixed(2)},${contentTop.toStringAsFixed(2)},'
        '${contentRight.toStringAsFixed(2)},${contentBottom.toStringAsFixed(2)} ',
      )
      ..write(
        'textRect=${textRect.left.toStringAsFixed(2)},${textRect.top.toStringAsFixed(2)},'
        '${textRect.right.toStringAsFixed(2)},${textRect.bottom.toStringAsFixed(2)} ',
      )
      ..write('insideContent=${(!hasTextOverflow).toString()}')
      ..write(' contentWidth=${contentWidth.toStringAsFixed(2)}')
      ..write(' contentHeight=${contentHeight.toStringAsFixed(2)}');
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: proofMessage.toString(),
        path: textPath,
      ),
    );

    final fitMessage = StringBuffer()
      ..write('TF_SCENE_TEXT_FIT_PROOF ')
      ..write('text=${text.id} ')
      ..write('estimatedWidth=${estimatedTextWidth.toStringAsFixed(2)} ')
      ..write('frameMaxWidth=')
      ..write(textFrameWidth?.toStringAsFixed(2) ?? 'null')
      ..write(' contentWidth=${contentWidth.toStringAsFixed(2)} ')
      ..write('overflow=')
      ..write(overflow ?? 'unset')
      ..write(' accepted=${(!hasTextOverflow).toString()}');
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: fitMessage.toString(),
        path: '$textPath.properties.textFrame',
      ),
    );
  }

  _ElementEntry? _findElement(
    List<ReFusionSceneProgramElement> elements, {
    required String byContains,
    String? kind,
  }) {
    for (var index = 0; index < elements.length; index += 1) {
      final element = elements[index];
      if (kind != null &&
          _normalizeToken(element.kind) != _normalizeToken(kind)) {
        continue;
      }
      if (_normalizeToken(element.id).contains(_normalizeToken(byContains))) {
        return _ElementEntry(index: index, element: element);
      }
    }
    return null;
  }

  _RectLike? _rectForElement(ReFusionSceneProgramElement element) {
    final position = _pointFromProperties(element.properties);
    final width =
        _doubleFromProperties(element.properties, const <String>['width']);
    final height =
        _doubleFromProperties(element.properties, const <String>['height']);
    if (position == null || width == null || height == null) {
      return null;
    }
    return _RectLike(
      left: position.dx - (width / 2),
      top: position.dy - (height / 2),
      right: position.dx + (width / 2),
      bottom: position.dy + (height / 2),
    );
  }

  _InsetsLike _insetsForShell(Map<String, Object?> properties) {
    final insetsObject = _mapFromProperties(
      properties,
      const <String>['contentInsets', 'padding'],
    );
    if (insetsObject == null) {
      return const _InsetsLike(left: 40, top: 16, right: 124, bottom: 16);
    }
    double read(String key, double fallback) =>
        _doubleFromMap(insetsObject, <String>[key]) ?? fallback;
    return _InsetsLike(
      left: read('left', 40),
      top: read('top', 16),
      right: read('right', 124),
      bottom: read('bottom', 16),
    );
  }

  _PointLike? _pointFromProperties(Map<String, Object?> properties) {
    final position =
        _mapFromProperties(properties, const <String>['position', 'translate']);
    if (position == null) {
      return null;
    }
    final x = _doubleFromMap(position, const <String>['x']);
    final y = _doubleFromMap(position, const <String>['y']);
    if (x == null || y == null) {
      return null;
    }
    return _PointLike(dx: x, dy: y);
  }

  double _estimateTextWidth(ReFusionSceneProgramElement textElement) {
    final text = (textElement.text ?? '').trim();
    final fontSize = _doubleFromProperties(
          textElement.properties,
          const <String>['fontSize'],
        ) ??
        32.0;
    final letterSpacing = _doubleFromProperties(
          textElement.properties,
          const <String>['letterSpacing', 'trackingAmount'],
        ) ??
        0.0;
    final characterWidth = fontSize * 0.54;
    final widthFromChars = text.length * characterWidth;
    final widthFromSpacing = math.max(0, text.length - 1) * letterSpacing;
    return widthFromChars + widthFromSpacing;
  }

  double _estimateTextHeight(ReFusionSceneProgramElement textElement) {
    final fontSize = _doubleFromProperties(
          textElement.properties,
          const <String>['fontSize'],
        ) ??
        32.0;
    final lineHeight = _doubleFromProperties(
          textElement.properties,
          const <String>['lineHeight'],
        ) ??
        1.0;
    return fontSize * math.max(1.0, lineHeight);
  }

  Map<String, Object?>? _mapFromProperties(
    Map<String, Object?> properties,
    List<String> keys,
  ) {
    final value = _propertyByNormalizedKey(properties, keys);
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, Object?>();
    }
    return null;
  }

  String? _stringFromProperties(
    Map<String, Object?> properties,
    List<String> keys,
  ) {
    final value = _propertyByNormalizedKey(properties, keys);
    return _asString(value);
  }

  String? _stringFromMap(Map<String, Object?>? map, List<String> keys) {
    if (map == null) {
      return null;
    }
    final value = _propertyByNormalizedKey(map, keys);
    return _asString(value);
  }

  double? _doubleFromProperties(
      Map<String, Object?> properties, List<String> keys) {
    final value = _propertyByNormalizedKey(properties, keys);
    return _asDouble(value);
  }

  double? _doubleFromMap(Map<String, Object?> map, List<String> keys) {
    final value = _propertyByNormalizedKey(map, keys);
    return _asDouble(value);
  }

  Object? _propertyByNormalizedKey(
      Map<String, Object?> map, List<String> keys) {
    final normalizedKeys = keys.map(_normalizeToken).toSet();
    for (final entry in map.entries) {
      if (normalizedKeys.contains(_normalizeToken(entry.key))) {
        return entry.value;
      }
    }
    return null;
  }

  String? _asString(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  String _normalizeToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}

class _ElementEntry {
  const _ElementEntry({
    required this.index,
    required this.element,
  });

  final int index;
  final ReFusionSceneProgramElement element;
}

class _RectLike {
  const _RectLike({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

class _InsetsLike {
  const _InsetsLike({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

class _PointLike {
  const _PointLike({
    required this.dx,
    required this.dy,
  });

  final double dx;
  final double dy;
}
