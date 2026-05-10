import '../models/refusion_scene_program_models.dart';

class ScenePromptInputBarComponentValidationResult {
  ScenePromptInputBarComponentValidationResult({
    required List<ReFusionSceneProgramIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class ScenePromptInputBarComponentValidator {
  const ScenePromptInputBarComponentValidator();

  static const String proofTag = 'TF_SCENE_PROMPT_INPUT_BAR_PROOF';
  static const String lifecycleProofTag =
      'TF_SCENE_PROMPT_INPUT_BAR_LIFECYCLE_PROOF';

  ScenePromptInputBarComponentValidationResult validate(
    ReFusionSceneProgram program,
  ) {
    final issues = <ReFusionSceneProgramIssue>[];
    final allEntries = <_ProgramElementEntry>[];
    for (var layerIndex = 0; layerIndex < program.layers.length; layerIndex++) {
      final layer = program.layers[layerIndex];
      for (var elementIndex = 0;
          elementIndex < layer.elements.length;
          elementIndex++) {
        allEntries.add(
          _ProgramElementEntry(
            layerIndex: layerIndex,
            elementIndex: elementIndex,
            layer: layer,
            element: layer.elements[elementIndex],
          ),
        );
      }
    }

    final shellEntries = allEntries.where((entry) {
      if (_normalizeToken(entry.element.kind) != 'shape') {
        return false;
      }
      final elementRole = _stringFromMap(
        entry.element.properties,
        const <String>['layoutRole', 'role'],
      );
      final normalizedRole = _normalizeToken(elementRole ?? '');
      if (normalizedRole == 'container') {
        final normalizedId = _normalizeToken(entry.element.id);
        return normalizedId.contains('promptshell') ||
            normalizedId.contains('inputbar');
      }
      return false;
    }).toList(growable: false);

    for (final shell in shellEntries) {
      _validatePromptShell(
        shell: shell,
        allEntries: allEntries,
        issues: issues,
      );
    }
    return ScenePromptInputBarComponentValidationResult(issues: issues);
  }

  void _validatePromptShell({
    required _ProgramElementEntry shell,
    required List<_ProgramElementEntry> allEntries,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final shellWindow = _windowFor(shell.layer);
    final textEntry = _firstMatchingEntry(
      allEntries,
      includes: const <String>['prompttext'],
      kind: 'text',
    );
    final sendButtonEntry = _firstMatchingEntry(
      allEntries,
      includes: const <String>['sendbutton'],
      kind: 'shape',
    );
    final plusIconEntry = _firstMatchingEntry(
      allEntries,
      includes: const <String>['plusicon', 'promptplus'],
      kind: 'icon',
    );
    final micIconEntry = _firstMatchingEntry(
      allEntries,
      includes: const <String>['micon', 'promptmic'],
      kind: 'icon',
    );
    final cursorEntry = _firstMatchingEntry(
      allEntries,
      includes: const <String>['promptcursor', 'cursor'],
      kind: 'shape',
    );
    final voiceIconEntry = _firstMatchingEntry(
      allEntries,
      includes: const <String>['voiceicon', 'promptvoice'],
      kind: 'icon',
    );

    if (textEntry == null || sendButtonEntry == null) {
      return;
    }

    final shellPath =
        'layers[${shell.layerIndex}].elements[${shell.elementIndex}]';
    final shellBorder = _doubleFromMap(
          shell.element.properties,
          const <String>['borderWidth', 'strokeWidth', 'stroke'],
        ) ??
        0.0;
    if (shellBorder < 1.0) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'PromptInputBar shell `${shell.element.id}` must keep a visible border (>= 1px).',
          path: '$shellPath.properties.borderWidth',
        ),
      );
    }

    final shellWidth = _doubleFromMap(
      shell.element.properties,
      const <String>['width'],
    );
    final shellHeight = _doubleFromMap(
      shell.element.properties,
      const <String>['height'],
    );
    if (shellWidth == null ||
        shellWidth < 560.0 ||
        shellWidth > 980.0 ||
        shellHeight == null ||
        shellHeight < 84.0 ||
        shellHeight > 140.0) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'PromptInputBar shell `${shell.element.id}` must keep intrinsic size bounds (width 560-980, height 84-140).',
          path: '$shellPath.properties.width',
        ),
      );
    }

    _validateParent(
      entry: textEntry,
      expectedParentId: shell.element.id,
      issues: issues,
      reason: 'Prompt text must be parented to prompt shell.',
    );
    _validateParent(
      entry: sendButtonEntry,
      expectedParentId: shell.element.id,
      issues: issues,
      reason: 'Send button must be parented to prompt shell.',
    );
    if (plusIconEntry != null) {
      _validateParent(
        entry: plusIconEntry,
        expectedParentId: shell.element.id,
        issues: issues,
        reason: 'Leading plus icon must be parented to prompt shell.',
      );
    }
    if (micIconEntry != null) {
      _validateParent(
        entry: micIconEntry,
        expectedParentId: shell.element.id,
        issues: issues,
        reason: 'Mic icon must be parented to prompt shell.',
      );
    }
    if (cursorEntry != null) {
      _validateParent(
        entry: cursorEntry,
        expectedParentId: shell.element.id,
        issues: issues,
        reason: 'Prompt cursor must be parented to prompt shell.',
      );
    }
    if (voiceIconEntry != null) {
      _validateParent(
        entry: voiceIconEntry,
        expectedParentId: sendButtonEntry.element.id,
        issues: issues,
        reason: 'Send glyph must be parented to send button.',
      );
    }

    final textPath =
        'layers[${textEntry.layerIndex}].elements[${textEntry.elementIndex}]';
    final textFrame = _mapFromMap(
      textEntry.element.properties,
      const <String>['textFrame'],
    );
    if (textFrame == null) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'PromptInputBar text `${textEntry.element.id}` must declare `textFrame`.',
          path: '$textPath.properties.textFrame',
        ),
      );
    } else {
      final maxLines =
          _doubleFromMap(textFrame, const <String>['maxLines']) ?? 0.0;
      if (maxLines > 1.5 || maxLines < 1.0) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'PromptInputBar text `${textEntry.element.id}` must stay single-line (`maxLines = 1`).',
            path: '$textPath.properties.textFrame.maxLines',
          ),
        );
      }
      final fitPolicy = _stringFromMap(
        textFrame,
        const <String>['fitPolicy'],
      );
      if (_normalizeToken(fitPolicy ?? '') != 'shrinktofit') {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'PromptInputBar text `${textEntry.element.id}` must use `fitPolicy: shrinkToFit`.',
            path: '$textPath.properties.textFrame.fitPolicy',
          ),
        );
      }
    }

    final fontWeight = _doubleFromMap(
      textEntry.element.properties,
      const <String>['fontWeight', 'weight'],
    );
    if (fontWeight != null && fontWeight > 500.0) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'PromptInputBar text `${textEntry.element.id}` should be regular weight (<= 500).',
          path: '$textPath.properties.fontWeight',
        ),
      );
    }
    final fontSize = _doubleFromMap(
      textEntry.element.properties,
      const <String>['fontSize'],
    );
    if (fontSize != null && (fontSize < 12.0 || fontSize > 34.0)) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'PromptInputBar text `${textEntry.element.id}` must use readable sizing (fontSize between 12 and 34).',
          path: '$textPath.properties.fontSize',
        ),
      );
    }
    final lineHeight = _doubleFromMap(
          textEntry.element.properties,
          const <String>['lineHeight'],
        ) ??
        1.0;
    final textVisualHeight =
        (fontSize ?? 16.0) * (lineHeight <= 0 ? 1.0 : lineHeight);
    if (shellHeight != null && shellHeight > 0) {
      final ratio = textVisualHeight / shellHeight;
      if (ratio < 0.22 || ratio > 0.42) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'PromptInputBar text `${textEntry.element.id}` ratio to shell height must stay within [0.22, 0.42]. Current=${ratio.toStringAsFixed(3)}.',
            path: '$textPath.properties.fontSize',
          ),
        );
      }
    }
    if (plusIconEntry != null) {
      _validateIconToTextRatio(
        iconEntry: plusIconEntry,
        textVisualHeight: textVisualHeight,
        issues: issues,
      );
    }
    if (micIconEntry != null) {
      _validateIconToTextRatio(
        iconEntry: micIconEntry,
        textVisualHeight: textVisualHeight,
        issues: issues,
      );
    }
    final hasTypewriterChannel = textEntry.element.channels.any(
      (channel) => _normalizeToken(channel.property) == 'typewriterprogress',
    );
    if (hasTypewriterChannel && cursorEntry != null) {
      final hasCursorMotionChannel = cursorEntry.element.channels.any(
        (channel) => _normalizeToken(channel.property) == 'positionx',
      );
      if (!hasCursorMotionChannel) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'PromptInputBar cursor `${cursorEntry.element.id}` must animate `positionX` when prompt text uses typewriterProgress.',
            path:
                'layers[${cursorEntry.layerIndex}].elements[${cursorEntry.elementIndex}].channels',
          ),
        );
      }
    }

    _validateLifecycleInsideShell(
      shell: shell,
      shellWindow: shellWindow,
      child: textEntry,
      issues: issues,
    );
    _validateLifecycleInsideShell(
      shell: shell,
      shellWindow: shellWindow,
      child: sendButtonEntry,
      issues: issues,
    );
    if (plusIconEntry != null) {
      _validateLifecycleInsideShell(
        shell: shell,
        shellWindow: shellWindow,
        child: plusIconEntry,
        issues: issues,
      );
    }
    if (micIconEntry != null) {
      _validateLifecycleInsideShell(
        shell: shell,
        shellWindow: shellWindow,
        child: micIconEntry,
        issues: issues,
      );
    }
    if (cursorEntry != null) {
      _validateLifecycleInsideShell(
        shell: shell,
        shellWindow: shellWindow,
        child: cursorEntry,
        issues: issues,
      );
    }
    if (voiceIconEntry != null) {
      _validateLifecycleInsideShell(
        shell: shell,
        shellWindow: shellWindow,
        child: voiceIconEntry,
        issues: issues,
      );
    }

    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$proofTag '
            'shell=${shell.element.id} '
            'text=${textEntry.element.id} '
            'sendButton=${sendButtonEntry.element.id} '
            'hasPlus=${(plusIconEntry != null).toString()} '
            'hasMic=${(micIconEntry != null).toString()} '
            'hasCursor=${(cursorEntry != null).toString()} '
            'hasVoiceIcon=${(voiceIconEntry != null).toString()}',
        path: shellPath,
      ),
    );
  }

  void _validateIconToTextRatio({
    required _ProgramElementEntry iconEntry,
    required double textVisualHeight,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final iconSize = _doubleFromMap(
          iconEntry.element.properties,
          const <String>['width', 'size'],
        ) ??
        0.0;
    if (iconSize <= 0 || textVisualHeight <= 0) {
      return;
    }
    final ratio = iconSize / textVisualHeight;
    if (ratio < 0.90 || ratio > 1.90) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'PromptInputBar icon `${iconEntry.element.id}` size must stay proportional to text height (ratio [0.90, 1.90]). Current=${ratio.toStringAsFixed(3)}.',
          path:
              'layers[${iconEntry.layerIndex}].elements[${iconEntry.elementIndex}].properties.width',
        ),
      );
    }
  }

  void _validateParent({
    required _ProgramElementEntry entry,
    required String expectedParentId,
    required List<ReFusionSceneProgramIssue> issues,
    required String reason,
  }) {
    final parentId = _stringFromMap(
      entry.element.properties,
      const <String>['parentId', 'parent', 'containerId', 'parentGroup'],
    );
    if (parentId == expectedParentId) {
      return;
    }
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.error,
        message:
            '$reason Expected parentId `$expectedParentId`, found `${parentId ?? 'unset'}` for `${entry.element.id}`.',
        path:
            'layers[${entry.layerIndex}].elements[${entry.elementIndex}].properties.parentId',
      ),
    );
  }

  void _validateLifecycleInsideShell({
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
        message: '$lifecycleProofTag '
            'shell=${shell.element.id} '
            'child=${child.element.id} '
            'shellRange=${shellWindow.startMs}-${shellWindow.endMs} '
            'childRange=${childWindow.startMs}-${childWindow.endMs} '
            'insideShell=${inside.toString()}',
        path: 'layers[${child.layerIndex}].elements[${child.elementIndex}]',
      ),
    );
  }

  _ProgramElementEntry? _firstMatchingEntry(
    List<_ProgramElementEntry> entries, {
    required List<String> includes,
    required String kind,
  }) {
    final normalizedIncludes = includes.map(_normalizeToken).toList();
    final normalizedKind = _normalizeToken(kind);
    for (final entry in entries) {
      if (_normalizeToken(entry.element.kind) != normalizedKind) {
        continue;
      }
      final normalizedId = _normalizeToken(entry.element.id);
      if (normalizedIncludes.any(normalizedId.contains)) {
        return entry;
      }
    }
    return null;
  }

  _TimeWindow _windowFor(ReFusionSceneProgramLayer layer) {
    return _TimeWindow(
      startMs: layer.startMs,
      endMs: layer.startMs + layer.durationMs,
    );
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
    final normalizedKeys = keys.map(_normalizeToken).toSet();
    for (final entry in source.entries) {
      if (normalizedKeys.contains(_normalizeToken(entry.key))) {
        return entry.value;
      }
    }
    return null;
  }

  String _normalizeToken(String value) {
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
