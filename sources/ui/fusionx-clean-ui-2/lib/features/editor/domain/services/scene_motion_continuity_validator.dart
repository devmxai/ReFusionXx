import '../models/refusion_scene_program_models.dart';

class SceneMotionContinuityValidationResult {
  SceneMotionContinuityValidationResult({
    required List<ReFusionSceneProgramIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneMotionContinuityValidator {
  const SceneMotionContinuityValidator();

  SceneMotionContinuityValidationResult validate(
    ReFusionSceneProgram program,
  ) {
    final issues = <ReFusionSceneProgramIssue>[];
    _lintPromptContinuity(program: program, issues: issues);
    return SceneMotionContinuityValidationResult(issues: issues);
  }

  void _lintPromptContinuity({
    required ReFusionSceneProgram program,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final entries = <_ElementEntry>[
      for (var layerIndex = 0; layerIndex < program.layers.length; layerIndex++)
        for (var elementIndex = 0;
            elementIndex < program.layers[layerIndex].elements.length;
            elementIndex++)
          _ElementEntry(
            layerIndex: layerIndex,
            elementIndex: elementIndex,
            layer: program.layers[layerIndex],
            element: program.layers[layerIndex].elements[elementIndex],
          ),
    ];

    final iconEntry = _findElement(entries, containsToken: 'appicon');
    final shellEntry = _findElement(entries, containsToken: 'promptshell');
    if (iconEntry == null || shellEntry == null) {
      return;
    }

    final icon = iconEntry.element;
    final shell = shellEntry.element;
    final continuity = _mapFromProperties(shell.properties, 'continuity');
    final declaredKind = _normalizeToken(
      _readString(continuity, 'kind') ?? _readString(continuity, 'mode') ?? '',
    );
    final declaredSource = _readString(continuity, 'sourceId');
    final hasDeclaration = declaredKind.isNotEmpty;
    final channels = <_ChannelRecord>[
      ..._collectLayerChannels(iconEntry.layer),
      ..._collectLayerChannels(shellEntry.layer),
      ..._collectElementChannels(iconEntry),
      ..._collectElementChannels(shellEntry),
    ];
    final iconOpacityRange = _channelTimeRange(
      channels,
      targetId: icon.id,
      propertyToken: 'opacity',
    );
    final shellOpacityRange = _channelTimeRange(
      channels,
      targetId: shell.id,
      propertyToken: 'opacity',
    );
    final overlaps = iconOpacityRange != null &&
        shellOpacityRange != null &&
        _rangesOverlap(iconOpacityRange, shellOpacityRange);
    final declaredDissolve =
        declaredKind == 'dissolve' || declaredKind == 'crossfade';
    final declaredMorph = declaredKind == 'morph' || declaredKind == 'handoff';

    if (declaredMorph && declaredSource != icon.id) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Continuity declaration on `${shell.id}` must reference sourceId `${icon.id}` for morph/handoff claims.',
          path:
              'layers[${shellEntry.layerIndex}].elements[${shellEntry.elementIndex}].properties.continuity.sourceId',
        ),
      );
    }

    if (overlaps && !hasDeclaration) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.warning,
          message:
              'Icon-to-prompt opacity overlap detected without continuity declaration. Add `continuity.kind` (`dissolve` or `morph`) on `${shell.id}`.',
          path:
              'layers[${shellEntry.layerIndex}].elements[${shellEntry.elementIndex}].properties.continuity',
        ),
      );
    }

    if (declaredMorph && !overlaps) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.warning,
          message:
              'Continuity kind `${declaredKind}` declared for `${shell.id}` but no overlapping icon/prompt timing was found.',
          path:
              'layers[${shellEntry.layerIndex}].elements[${shellEntry.elementIndex}].properties.continuity.kind',
        ),
      );
    }

    final proof = StringBuffer()
      ..write('TF_SCENE_MOTION_CONTINUITY_PROOF ')
      ..write('layer=${shellEntry.layer.id} ')
      ..write('icon=${icon.id} ')
      ..write('prompt=${shell.id} ')
      ..write('declaredKind=${declaredKind.isEmpty ? 'none' : declaredKind} ')
      ..write('declaredSource=${declaredSource ?? 'none'} ')
      ..write('opacityOverlap=${overlaps.toString()} ')
      ..write(
          'accepted=${(declaredDissolve || declaredMorph || !overlaps).toString()} ')
      ..write('fallbackReason=')
      ..write(
        overlaps && !hasDeclaration ? 'missing_continuity_declaration' : 'none',
      );
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: proof.toString(),
        path:
            'layers[${shellEntry.layerIndex}].elements[${shellEntry.elementIndex}].properties.continuity',
      ),
    );
  }

  _ElementEntry? _findElement(
    List<_ElementEntry> elements, {
    required String containsToken,
  }) {
    final target = _normalizeToken(containsToken);
    for (final entry in elements) {
      final id = _normalizeToken(entry.element.id);
      if (id.contains(target)) {
        return entry;
      }
    }
    return null;
  }

  List<_ChannelRecord> _collectLayerChannels(ReFusionSceneProgramLayer layer) {
    return layer.channels
        .map(
          (channel) => _ChannelRecord(
            target: channel.target,
            property: channel.property,
            keyframes: channel.keyframes,
            baseTimeMs: layer.startMs,
          ),
        )
        .toList(growable: false);
  }

  List<_ChannelRecord> _collectElementChannels(_ElementEntry entry) {
    return entry.element.channels
        .map(
          (channel) => _ChannelRecord(
            target: channel.target.isEmpty ? entry.element.id : channel.target,
            property: channel.property,
            keyframes: channel.keyframes,
            baseTimeMs: entry.layer.startMs,
          ),
        )
        .toList(growable: false);
  }

  _TimeRange? _channelTimeRange(
    List<_ChannelRecord> channels, {
    required String targetId,
    required String propertyToken,
  }) {
    _TimeRange? range;
    final normalizedProperty = _normalizeToken(propertyToken);
    for (final channel in channels) {
      if (_normalizeToken(channel.target) != _normalizeToken(targetId)) {
        continue;
      }
      if (_normalizeToken(channel.property) != normalizedProperty) {
        continue;
      }
      if (channel.keyframes.isEmpty) {
        continue;
      }
      final times = channel.keyframes
          .map((keyframe) => channel.baseTimeMs + keyframe.timeMs);
      final channelRange = _TimeRange(
        startMs: times.reduce((left, right) => left < right ? left : right),
        endMs: times.reduce((left, right) => left > right ? left : right),
      );
      if (range == null) {
        range = channelRange;
      } else {
        range = _TimeRange(
          startMs: range.startMs < channelRange.startMs
              ? range.startMs
              : channelRange.startMs,
          endMs: range.endMs > channelRange.endMs
              ? range.endMs
              : channelRange.endMs,
        );
      }
    }
    return range;
  }

  bool _rangesOverlap(_TimeRange a, _TimeRange b) {
    return a.startMs <= b.endMs && b.startMs <= a.endMs;
  }

  Map<String, Object?>? _mapFromProperties(
    Map<String, Object?> properties,
    String key,
  ) {
    final normalized = _normalizeToken(key);
    for (final entry in properties.entries) {
      if (_normalizeToken(entry.key) != normalized) {
        continue;
      }
      final value = entry.value;
      if (value is Map) {
        return value.cast<String, Object?>();
      }
      return null;
    }
    return null;
  }

  String? _readString(Map<String, Object?>? map, String key) {
    if (map == null) {
      return null;
    }
    final normalized = _normalizeToken(key);
    for (final entry in map.entries) {
      if (_normalizeToken(entry.key) != normalized) {
        continue;
      }
      final value = entry.value;
      if (value is! String) {
        return null;
      }
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  String _normalizeToken(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

class _ElementEntry {
  const _ElementEntry({
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

class _TimeRange {
  const _TimeRange({
    required this.startMs,
    required this.endMs,
  });

  final int startMs;
  final int endMs;
}

class _ChannelRecord {
  const _ChannelRecord({
    required this.target,
    required this.property,
    required this.keyframes,
    required this.baseTimeMs,
  });

  final String target;
  final String property;
  final List<ReFusionSceneProgramKeyframe> keyframes;
  final int baseTimeMs;
}
