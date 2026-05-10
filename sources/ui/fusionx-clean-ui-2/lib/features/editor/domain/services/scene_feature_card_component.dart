import 'dart:math' as math;

import '../models/refusion_scene_program_models.dart';

class SceneFeatureCardComponentValidationResult {
  SceneFeatureCardComponentValidationResult({
    required List<ReFusionSceneProgramIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneFeatureCardComponentValidator {
  const SceneFeatureCardComponentValidator();

  static const String proofTag = 'TF_SCENE_FEATURE_CARD_PROOF';
  static const String lifecycleProofTag =
      'TF_SCENE_FEATURE_CARD_LIFECYCLE_PROOF';

  static const Set<String> _allowedBodyFitPolicies = <String>{
    'shrinktofit',
    'wraptolines',
    'wrap',
  };

  SceneFeatureCardComponentValidationResult validate(
    ReFusionSceneProgram program,
  ) {
    final issues = <ReFusionSceneProgramIssue>[];
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

    final featureCardShells = entries.where(_isFeatureCardShell).toList();
    for (final shell in featureCardShells) {
      _validateFeatureCard(
        shell: shell,
        entries: entries,
        issues: issues,
      );
    }

    return SceneFeatureCardComponentValidationResult(issues: issues);
  }

  bool _isFeatureCardShell(_ProgramElementEntry entry) {
    if (_normalize(entry.element.kind) != 'shape') {
      return false;
    }
    final role = _normalize(
      _stringFromMap(
            entry.element.properties,
            const <String>['layoutRole', 'role'],
          ) ??
          '',
    );
    if (role != 'container') {
      return false;
    }
    final componentType = _normalize(
      _stringFromMap(
            entry.element.properties,
            const <String>['componentType', 'component', 'semanticType'],
          ) ??
          '',
    );
    if (componentType == 'featurecard') {
      return true;
    }
    final normalizedId = _normalize(entry.element.id);
    return normalizedId.contains('filecard') && normalizedId.contains('shell');
  }

  void _validateFeatureCard({
    required _ProgramElementEntry shell,
    required List<_ProgramElementEntry> entries,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final shellPath =
        'layers[${shell.layerIndex}].elements[${shell.elementIndex}]';
    final shellWindow = _windowFor(shell.layer);
    final shellRect = _rectFor(shell.element);
    final normalizedShellPrefix = _detectCardPrefix(shell.element.id);

    final childEntries = entries.where((entry) {
      final parentId = _stringFromMap(
        entry.element.properties,
        const <String>['parentId', 'parent', 'containerId', 'parentGroup'],
      );
      return parentId == shell.element.id;
    }).toList();

    final iconContainer = _firstMatchingChild(
      childEntries,
      kind: 'shape',
      includes: const <String>['iconbox', 'iconbg', 'iconcontainer'],
    );
    final iconGlyph = _firstMatchingIconGlyph(
      entries: entries,
      shellId: shell.element.id,
      iconContainerId: iconContainer?.element.id,
      fallbackPrefix: normalizedShellPrefix,
    );
    final titleEntry = _firstTextEntry(
      childEntries: childEntries,
      includes: const <String>['title'],
      fallbackPrefix: normalizedShellPrefix,
    );
    final bodyEntries = _bodyEntries(
      childEntries: childEntries,
      fallbackPrefix: normalizedShellPrefix,
    );

    if (titleEntry == null || bodyEntries.isEmpty) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'FEATURE_TEXT_CLIPPED FeatureCard `${shell.element.id}` must expose `title` and `body` text children.',
          path: shellPath,
        ),
      );
      return;
    }

    _validateLifecycle(
      shell: shell,
      shellWindow: shellWindow,
      child: titleEntry,
      issues: issues,
    );
    for (final body in bodyEntries) {
      _validateLifecycle(
        shell: shell,
        shellWindow: shellWindow,
        child: body,
        issues: issues,
      );
    }
    if (iconContainer != null) {
      _validateLifecycle(
        shell: shell,
        shellWindow: shellWindow,
        child: iconContainer,
        issues: issues,
      );
    }
    if (iconGlyph != null) {
      _validateLifecycle(
        shell: shell,
        shellWindow: shellWindow,
        child: iconGlyph,
        issues: issues,
      );
    }

    _validateTitleBodyOrder(
      shellPath: shellPath,
      titleEntry: titleEntry,
      bodyEntries: bodyEntries,
      issues: issues,
    );
    _validateTextFrames(
      shellRect: shellRect,
      shellPath: shellPath,
      titleEntry: titleEntry,
      bodyEntries: bodyEntries,
      issues: issues,
    );
    _validateSentenceFragments(bodyEntries: bodyEntries, issues: issues);
    _validateIconGeometry(
      shellRect: shellRect,
      shellPath: shellPath,
      iconContainer: iconContainer,
      iconGlyph: iconGlyph,
      issues: issues,
    );

    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$proofTag '
            'shell=${shell.element.id} '
            'title=${titleEntry.element.id} '
            'bodyCount=${bodyEntries.length} '
            'iconContainer=${iconContainer?.element.id ?? 'none'} '
            'iconGlyph=${iconGlyph?.element.id ?? 'none'}',
        path: shellPath,
      ),
    );
  }

  void _validateTitleBodyOrder({
    required String shellPath,
    required _ProgramElementEntry titleEntry,
    required List<_ProgramElementEntry> bodyEntries,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final titleY = _positionFor(titleEntry.element)?.dy;
    if (titleY == null) {
      return;
    }
    final sortedBodies = bodyEntries.toList()
      ..sort((a, b) {
        final ay = _positionFor(a.element)?.dy ?? 0;
        final by = _positionFor(b.element)?.dy ?? 0;
        return ay.compareTo(by);
      });
    final firstBodyY = _positionFor(sortedBodies.first.element)?.dy;
    if (firstBodyY == null) {
      return;
    }
    final gap = firstBodyY - titleY;
    if (gap <= 4) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'FEATURE_BODY_BASELINE_OUT_OF_SLOT FeatureCard `${titleEntry.element.id}` body baseline must remain below title baseline.',
          path: shellPath,
        ),
      );
    }
  }

  void _validateTextFrames({
    required _RectLike? shellRect,
    required String shellPath,
    required _ProgramElementEntry titleEntry,
    required List<_ProgramElementEntry> bodyEntries,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final titleFrame = _mapFromMap(
      titleEntry.element.properties,
      const <String>['textFrame'],
    );
    if (titleFrame == null) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'FEATURE_TEXT_CLIPPED Title `${titleEntry.element.id}` must define `textFrame`.',
          path:
              'layers[${titleEntry.layerIndex}].elements[${titleEntry.elementIndex}].properties.textFrame',
        ),
      );
    }
    for (final body in bodyEntries) {
      final bodyFrame = _mapFromMap(
        body.element.properties,
        const <String>['textFrame'],
      );
      final bodyPath =
          'layers[${body.layerIndex}].elements[${body.elementIndex}].properties.textFrame';
      if (bodyFrame == null) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'FEATURE_TEXT_CLIPPED Body `${body.element.id}` must define `textFrame`.',
            path: bodyPath,
          ),
        );
        continue;
      }

      final fitPolicy = _normalize(
        _stringFromMap(bodyFrame, const <String>['fitPolicy']) ?? '',
      );
      if (!_allowedBodyFitPolicies.contains(fitPolicy)) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'FEATURE_TEXT_CLIPPED Body `${body.element.id}` must use `fitPolicy` of shrinkToFit or wrapToLines.',
            path: '$bodyPath.fitPolicy',
          ),
        );
      }

      final frameWidth = _doubleFromMap(bodyFrame, const <String>['width']);
      final frameHeight = _doubleFromMap(bodyFrame, const <String>['height']);
      final fontSize = _doubleFromMap(
            body.element.properties,
            const <String>['fontSize'],
          ) ??
          16;
      final lineHeight = _doubleFromMap(
            body.element.properties,
            const <String>['lineHeight'],
          ) ??
          1.2;
      final maxLines =
          _doubleFromMap(bodyFrame, const <String>['maxLines']) ?? 1;
      if (frameWidth == null || frameHeight == null || frameWidth <= 0) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'FEATURE_TEXT_CLIPPED Body `${body.element.id}` requires positive textFrame width/height.',
            path: bodyPath,
          ),
        );
        continue;
      }

      if (shellRect != null && frameWidth > shellRect.width - 24) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'FEATURE_TEXT_CLIPPED Body `${body.element.id}` textFrame width exceeds shell safe content width.',
            path: '$bodyPath.width',
          ),
        );
      }

      final estimatedWidth = _estimateTextWidth(body.element, fontSize);
      final estimatedLineHeight = fontSize * lineHeight;
      final estimatedLines = math.max(1, (estimatedWidth / frameWidth).ceil());
      final maxFrameLines =
          math.max(1, (frameHeight / estimatedLineHeight).floor());
      final allowedLines =
          math.max(1, math.min(maxLines.ceil(), maxFrameLines));
      if (estimatedLines > allowedLines) {
        final minFontSize = _doubleFromMap(
              bodyFrame,
              const <String>['minFontSize'],
            ) ??
            (fontSize * 0.7);
        final shrinkRatio = frameWidth / estimatedWidth;
        final effectiveFontSize = fontSize * shrinkRatio;
        final canShrink = fitPolicy == 'shrinktofit' &&
            effectiveFontSize >= minFontSize - 0.1;
        final canWrap = (fitPolicy == 'wraptolines' || fitPolicy == 'wrap') &&
            estimatedLines <= maxLines.ceil();
        if (!canShrink && !canWrap) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message:
                  'FEATURE_TEXT_CLIPPED Body `${body.element.id}` overflows slot bounds.',
              path: bodyPath,
            ),
          );
        }
      }
    }
  }

  void _validateSentenceFragments({
    required List<_ProgramElementEntry> bodyEntries,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    for (final body in bodyEntries) {
      final text = (body.element.text ?? '').trim().toLowerCase();
      if (text.isEmpty) {
        continue;
      }
      final dangling = text.endsWith(',') ||
          text.endsWith(' and') ||
          text.endsWith(' or') ||
          text.endsWith(' the') ||
          text.endsWith(' with') ||
          text.endsWith(' to');
      if (!dangling) {
        continue;
      }
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'FEATURE_SENTENCE_CUT_MID_PHRASE Body `${body.element.id}` ends with a dangling phrase fragment.',
          path:
              'layers[${body.layerIndex}].elements[${body.elementIndex}].text',
        ),
      );
    }
  }

  void _validateIconGeometry({
    required _RectLike? shellRect,
    required String shellPath,
    required _ProgramElementEntry? iconContainer,
    required _ProgramElementEntry? iconGlyph,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    if (iconContainer == null || iconGlyph == null) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'FEATURE_ICON_MISALIGNED FeatureCard must include icon container and icon glyph children.',
          path: shellPath,
        ),
      );
      return;
    }

    final containerRect = _rectFor(iconContainer.element);
    final glyphRect = _resolvedChildRect(
      parentRect: containerRect,
      child: iconGlyph.element,
    );
    if (containerRect == null || glyphRect == null) {
      return;
    }

    final centerDx = (containerRect.centerX - glyphRect.centerX).abs();
    final centerDy = (containerRect.centerY - glyphRect.centerY).abs();
    final centerDelta =
        math.sqrt((centerDx * centerDx) + (centerDy * centerDy));
    final allowedDelta = math.max(3.0, containerRect.minDimension * 0.12);
    if (centerDelta > allowedDelta) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'FEATURE_ICON_MISALIGNED Icon `${iconGlyph.element.id}` drifts from icon container center.',
          path:
              'layers[${iconGlyph.layerIndex}].elements[${iconGlyph.elementIndex}]',
        ),
      );
    }

    if (shellRect != null) {
      final ratio = glyphRect.height / shellRect.height;
      if (ratio < 0.10 || ratio > 0.45) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'FEATURE_ICON_MISALIGNED Icon `${iconGlyph.element.id}` size is not proportional to card shell.',
            path:
                'layers[${iconGlyph.layerIndex}].elements[${iconGlyph.elementIndex}]',
          ),
        );
      }
    }
  }

  _ProgramElementEntry? _firstMatchingChild(
    List<_ProgramElementEntry> childEntries, {
    required String kind,
    required List<String> includes,
  }) {
    final normalizedKind = _normalize(kind);
    final tokens = includes.map(_normalize).toList();
    for (final entry in childEntries) {
      if (_normalize(entry.element.kind) != normalizedKind) {
        continue;
      }
      final id = _normalize(entry.element.id);
      if (tokens.any(id.contains)) {
        return entry;
      }
    }
    return null;
  }

  _ProgramElementEntry? _firstMatchingIconGlyph({
    required List<_ProgramElementEntry> entries,
    required String shellId,
    required String? iconContainerId,
    required String fallbackPrefix,
  }) {
    for (final entry in entries) {
      if (_normalize(entry.element.kind) != 'icon') {
        continue;
      }
      final parentId = _stringFromMap(
        entry.element.properties,
        const <String>['parentId', 'parent', 'containerId', 'parentGroup'],
      );
      if (parentId == shellId ||
          (iconContainerId != null && parentId == iconContainerId)) {
        return entry;
      }
      final normalizedId = _normalize(entry.element.id);
      if (fallbackPrefix.isNotEmpty &&
          normalizedId.contains(fallbackPrefix) &&
          normalizedId.contains('icon')) {
        return entry;
      }
    }
    return null;
  }

  _ProgramElementEntry? _firstTextEntry({
    required List<_ProgramElementEntry> childEntries,
    required List<String> includes,
    required String fallbackPrefix,
  }) {
    final tokens = includes.map(_normalize).toList();
    for (final entry in childEntries) {
      if (_normalize(entry.element.kind) != 'text') {
        continue;
      }
      final normalizedId = _normalize(entry.element.id);
      if (tokens.any(normalizedId.contains)) {
        return entry;
      }
    }
    for (final entry in childEntries) {
      if (_normalize(entry.element.kind) != 'text') {
        continue;
      }
      final normalizedId = _normalize(entry.element.id);
      if (fallbackPrefix.isNotEmpty && normalizedId.contains(fallbackPrefix)) {
        return entry;
      }
    }
    return null;
  }

  List<_ProgramElementEntry> _bodyEntries({
    required List<_ProgramElementEntry> childEntries,
    required String fallbackPrefix,
  }) {
    final results = <_ProgramElementEntry>[];
    for (final entry in childEntries) {
      if (_normalize(entry.element.kind) != 'text') {
        continue;
      }
      final normalizedId = _normalize(entry.element.id);
      final isBody = normalizedId.contains('body') ||
          normalizedId.contains('status') ||
          normalizedId.contains('line');
      if (isBody) {
        results.add(entry);
      }
    }
    if (results.isNotEmpty) {
      return results;
    }
    return childEntries
        .where((entry) {
          if (_normalize(entry.element.kind) != 'text') {
            return false;
          }
          final normalizedId = _normalize(entry.element.id);
          return fallbackPrefix.isNotEmpty &&
              normalizedId.contains(fallbackPrefix);
        })
        .skip(1)
        .toList();
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
        message:
            '${inside ? lifecycleProofTag : 'FEATURE_CHILD_VISIBLE_AFTER_CARD_EXIT'} '
            'shell=${shell.element.id} '
            'child=${child.element.id} '
            'shellRange=${shellWindow.startMs}-${shellWindow.endMs} '
            'childRange=${childWindow.startMs}-${childWindow.endMs} '
            'insideShell=${inside.toString()}',
        path: 'layers[${child.layerIndex}].elements[${child.elementIndex}]',
      ),
    );
  }

  _TimeWindow _windowFor(ReFusionSceneProgramLayer layer) {
    return _TimeWindow(
      startMs: layer.startMs,
      endMs: layer.startMs + layer.durationMs,
    );
  }

  _RectLike? _rectFor(ReFusionSceneProgramElement element) {
    final position = _positionFor(element);
    final width = _doubleFromMap(element.properties, const <String>['width']);
    final height = _doubleFromMap(element.properties, const <String>['height']);
    if (position == null || width == null || height == null) {
      return null;
    }
    return _RectLike.fromCenter(
      centerX: position.dx,
      centerY: position.dy,
      width: width,
      height: height,
    );
  }

  _RectLike? _resolvedChildRect({
    required _RectLike? parentRect,
    required ReFusionSceneProgramElement child,
  }) {
    final childRect = _rectFor(child);
    if (childRect == null || parentRect == null) {
      return childRect;
    }
    final position = child.properties['position'];
    if (position is! Map<String, Object?>) {
      return childRect;
    }
    final localX = _doubleFromMap(position, const <String>['x']);
    final localY = _doubleFromMap(position, const <String>['y']);
    if (localX == null || localY == null) {
      return childRect;
    }
    final localWithinParent = localX.abs() <= (parentRect.width / 2.0) + 1.0 &&
        localY.abs() <= (parentRect.height / 2.0) + 1.0;
    final parentIsOffset =
        parentRect.centerX.abs() > (parentRect.width / 2.0) + 20.0 ||
            parentRect.centerY.abs() > (parentRect.height / 2.0) + 20.0;
    if (!localWithinParent || !parentIsOffset) {
      return childRect;
    }
    return _RectLike.fromCenter(
      centerX: parentRect.centerX + localX,
      centerY: parentRect.centerY + localY,
      width: childRect.width,
      height: childRect.height,
    );
  }

  _PointLike? _positionFor(ReFusionSceneProgramElement element) {
    final position = element.properties['position'];
    if (position is! Map<String, Object?>) {
      return null;
    }
    final x = _doubleFromMap(position, const <String>['x']);
    final y = _doubleFromMap(position, const <String>['y']);
    if (x == null || y == null) {
      return null;
    }
    return _PointLike(dx: x, dy: y);
  }

  double _estimateTextWidth(
      ReFusionSceneProgramElement element, double fontSize) {
    final text = element.text ?? '';
    if (text.isEmpty) {
      return 0;
    }
    final letterSpacing = _doubleFromMap(
          element.properties,
          const <String>['letterSpacing'],
        ) ??
        0;
    final base = text.length * fontSize * 0.50;
    final tracking = math.max(0, text.length - 1) * letterSpacing;
    return base + tracking;
  }

  String _detectCardPrefix(String id) {
    final normalized = _normalize(id);
    final fileCardIndex = normalized.indexOf('filecard');
    if (fileCardIndex >= 0) {
      return normalized.substring(fileCardIndex);
    }
    final cardIndex = normalized.indexOf('card');
    if (cardIndex >= 0) {
      return normalized.substring(cardIndex);
    }
    return '';
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
  double get height => bottom - top;
  double get centerX => (left + right) / 2.0;
  double get centerY => (top + bottom) / 2.0;
  double get minDimension => math.min(width, height);
}

class _PointLike {
  const _PointLike({
    required this.dx,
    required this.dy,
  });

  final double dx;
  final double dy;
}
