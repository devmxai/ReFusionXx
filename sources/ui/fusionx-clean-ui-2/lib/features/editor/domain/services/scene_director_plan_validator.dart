import '../models/refusion_scene_program_models.dart';
import '../models/scene_director_brief_models.dart';

const String kSceneDirectorBriefProofTag = 'TF_SCENE_DIRECTOR_BRIEF_PROOF';

class SceneDirectorPlanValidationResult {
  SceneDirectorPlanValidationResult({
    required this.issues,
    this.brief,
  });

  final SceneDirectorBrief? brief;
  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid =>
      brief != null &&
      !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneDirectorPlanValidator {
  const SceneDirectorPlanValidator();

  static const Set<String> _allowedImportance = <String>{
    'primary',
    'secondary',
    'supporting',
    'accent',
    'background',
  };

  SceneDirectorPlanValidationResult validate(Object? raw) {
    final issues = <ReFusionSceneProgramIssue>[];
    final map = _normalizeRoot(raw, issues);
    if (map == null) {
      return SceneDirectorPlanValidationResult(
        issues: List.unmodifiable(issues),
      );
    }

    final intent = _readString(map['intent']);
    final audience = _readString(map['audience']) ?? 'general';
    final mood = _readString(map['mood']) ?? '';
    final primaryFocus = _readString(map['primaryFocus']) ?? '';
    final rhythm = _readString(map['rhythm']) ?? '';
    final aspect = _readString(map['aspect']) ?? r'$canvas.vertical9x16';
    final durationIntent =
        _readString(map['durationIntent']) ?? r'$duration.medium';
    final brandContext = _readString(map['brandContext']);
    final visualStyle = _readString(map['visualStyle']);
    final metadata = _readMap(map['metadata']) ?? const <String, Object?>{};

    if (intent == null || intent.isEmpty) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Director Brief must include a non-empty `intent`.',
          path: 'directorBrief.intent',
        ),
      );
    }
    if (mood.isEmpty) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.warning,
          message:
              'Director Brief did not include `mood`; using neutral defaults.',
          path: 'directorBrief.mood',
        ),
      );
    }
    if (rhythm.isEmpty) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.warning,
          message:
              'Director Brief did not include `rhythm`; using standard pacing.',
          path: 'directorBrief.rhythm',
        ),
      );
    }

    final elements = _readElements(map['elements'], issues);
    if (elements.isEmpty) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Director Brief must include at least one element.',
          path: 'directorBrief.elements',
        ),
      );
    }

    final primaryCount = elements
        .where((element) => _normalize(element.importance) == 'primary')
        .length;
    if (primaryCount == 0) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Director Brief must define at least one `primary` element.',
          path: 'directorBrief.elements',
        ),
      );
    }
    if (primaryCount > 2) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Director Brief defines too many primary elements for one scene beat hierarchy.',
          path: 'directorBrief.elements',
        ),
      );
    }

    final duplicateIds = <String>{};
    final seenIds = <String>{};
    for (final element in elements) {
      final id = element.id?.trim();
      if (id == null || id.isEmpty) {
        continue;
      }
      if (!seenIds.add(id)) {
        duplicateIds.add(id);
      }
    }
    for (final duplicateId in duplicateIds) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Director Brief contains duplicate element id `$duplicateId`.',
          path: 'directorBrief.elements',
        ),
      );
    }

    final luxuryMood = _normalize(mood).contains('luxury') ||
        _normalize(mood).contains('minimal');
    if (luxuryMood) {
      final energeticMotion = elements.any((element) {
        final hint = _normalize(element.motionHint ?? '');
        return hint.contains('bounce') ||
            hint.contains('wiggle') ||
            hint.contains('shake') ||
            hint.contains('stamp');
      });
      if (energeticMotion) {
        issues.add(
          const ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Director Brief mood is luxury/minimal but motion hints are highly bouncy.',
            path: 'directorBrief.elements.motionHint',
          ),
        );
      }
    }

    final brief = SceneDirectorBrief(
      intent: intent ?? '',
      audience: audience,
      mood: mood.isEmpty ? 'neutral professional' : mood,
      primaryFocus: primaryFocus.isEmpty ? 'primary element' : primaryFocus,
      rhythm: rhythm.isEmpty ? 'intro hold outro' : rhythm,
      aspect: aspect,
      durationIntent: durationIntent,
      brandContext: brandContext,
      visualStyle: visualStyle,
      elements: elements,
      metadata: metadata,
    );

    final hasErrors = issues.any(
      (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
    );
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$kSceneDirectorBriefProofTag '
            'intent=${_singleToken(brief.intent)} '
            'mood=${_singleToken(brief.mood)} '
            'rhythm=${_singleToken(brief.rhythm)} '
            'aspect=${_singleToken(brief.aspect)} '
            'primaryFocus=${_singleToken(brief.primaryFocus)} '
            'elementCount=${brief.elements.length} '
            'validated=${(!hasErrors).toString()} '
            'rejectionReason=${hasErrors ? 'validation_error' : 'none'} '
            'fallbackReason=none',
        path: 'directorBrief',
      ),
    );

    return SceneDirectorPlanValidationResult(
      brief: hasErrors ? null : brief,
      issues: List.unmodifiable(issues),
    );
  }

  Map<String, Object?>? _normalizeRoot(
    Object? raw,
    List<ReFusionSceneProgramIssue> issues,
  ) {
    if (raw is! Map) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Director Brief payload must be a JSON object.',
          path: 'directorBrief',
        ),
      );
      return null;
    }
    final map = raw.cast<String, Object?>();
    final nested = map['directorBrief'];
    if (nested is Map) {
      return nested.cast<String, Object?>();
    }
    return map;
  }

  List<SceneDirectorBriefElement> _readElements(
    Object? raw,
    List<ReFusionSceneProgramIssue> issues,
  ) {
    if (raw is! List) {
      return const <SceneDirectorBriefElement>[];
    }
    final elements = <SceneDirectorBriefElement>[];
    for (var index = 0; index < raw.length; index += 1) {
      final path = 'directorBrief.elements[$index]';
      final value = raw[index];
      if (value is! Map) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Director element must be an object.',
            path: path,
          ),
        );
        continue;
      }
      final map = value.cast<String, Object?>();
      final kind = _readString(map['kind']) ?? '';
      final importance = _readString(map['importance']) ?? '';
      if (kind.isEmpty) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Director element must include `kind`.',
            path: '$path.kind',
          ),
        );
      }
      if (importance.isEmpty) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Director element must include `importance`.',
            path: '$path.importance',
          ),
        );
      } else if (!_allowedImportance.contains(_normalize(importance))) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Unsupported director importance `$importance`.',
            path: '$path.importance',
          ),
        );
      }
      final cards = _readCards(map['cards'], issues, '$path.cards');
      if (_normalize(kind) == 'featurecardgroup' && cards.isEmpty) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Feature card groups must include non-empty `cards` payloads.',
            path: '$path.cards',
          ),
        );
      }
      elements.add(
        SceneDirectorBriefElement(
          id: _readString(map['id']),
          kind: kind,
          importance: importance,
          text: _readString(map['text']),
          motionHint: _readString(map['motionHint']),
          iconToken: _readString(map['iconToken']) ?? _readString(map['icon']),
          brandToken:
              _readString(map['brandToken']) ?? _readString(map['brand']),
          cards: cards,
          properties: _readMap(map['properties']) ?? const <String, Object?>{},
        ),
      );
    }
    return elements;
  }

  List<SceneDirectorBriefCard> _readCards(
    Object? raw,
    List<ReFusionSceneProgramIssue> issues,
    String path,
  ) {
    if (raw is! List) {
      return const <SceneDirectorBriefCard>[];
    }
    final cards = <SceneDirectorBriefCard>[];
    for (var index = 0; index < raw.length; index += 1) {
      final value = raw[index];
      final cardPath = '$path[$index]';
      if (value is! Map) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Director card must be an object.',
            path: cardPath,
          ),
        );
        continue;
      }
      final map = value.cast<String, Object?>();
      final label = _readString(map['label']) ?? '';
      final body = _readString(map['body']) ?? '';
      if (label.isEmpty || body.isEmpty) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Director card must include non-empty `label` and `body`.',
            path: cardPath,
          ),
        );
      }
      cards.add(
        SceneDirectorBriefCard(
          label: label,
          body: body,
          iconToken: _readString(map['iconToken']) ?? _readString(map['icon']),
          brandToken:
              _readString(map['brandToken']) ?? _readString(map['brand']),
        ),
      );
    }
    return cards;
  }

  Map<String, Object?>? _readMap(Object? raw) {
    if (raw is Map) {
      return raw.cast<String, Object?>();
    }
    return null;
  }

  String? _readString(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  String _singleToken(String value) {
    final compact = value.trim().replaceAll(RegExp(r'\s+'), '_');
    return compact.isEmpty ? 'none' : compact;
  }
}
