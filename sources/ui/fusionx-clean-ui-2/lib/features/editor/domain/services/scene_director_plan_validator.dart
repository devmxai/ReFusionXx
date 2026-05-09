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
  static const Set<String> _allowedAspects = <String>{
    r'$canvas.vertical9x16',
    r'$canvas.widescreen16x9',
    r'$canvas.square1x1',
    r'$canvas.portrait4x5',
  };
  static const Set<String> _allowedDurationIntents = <String>{
    r'$duration.fast',
    r'$duration.medium',
    r'$duration.deliberate',
    r'$duration.slow',
  };
  static const Set<String> _vagueIntentTokens = <String>{
    'makesomethingcool',
    'makecoolvideo',
    'coolvideo',
    'nicevideo',
    'makeitnice',
    'goodscene',
    'somethingcreative',
  };
  static const Set<String> _highEnergyMotionTokens = <String>{
    'bounce',
    'wiggle',
    'shake',
    'stamp',
    'whip',
    'pop',
  };
  static const Set<String> _playfulBrands = <String>{
    r'$brand.tiktok',
    r'$brand.snapchat',
    r'$brand.instagram',
    r'$brand.threads',
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
    final audience = _readString(map['audience']) ?? '';
    final mood = _readString(map['mood']) ?? '';
    final primaryFocus = _readString(map['primaryFocus']) ?? '';
    final rhythm = _readString(map['rhythm']) ?? '';
    final aspect = _readString(map['aspect']) ?? '';
    final durationIntent = _readString(map['durationIntent']) ?? '';
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
    } else {
      final token = _normalize(intent);
      if (_vagueIntentTokens.contains(token) ||
          token.contains('somethingcool') ||
          token.contains('coolthing')) {
        issues.add(
          const ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Director Brief intent is too vague. Provide a concrete creative objective.',
            path: 'directorBrief.intent',
          ),
        );
      }
    }
    if (audience.isEmpty) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Director Brief must include `audience`.',
          path: 'directorBrief.audience',
        ),
      );
    }
    if (mood.isEmpty) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Director Brief must include `mood`.',
          path: 'directorBrief.mood',
        ),
      );
    }
    if (primaryFocus.isEmpty) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Director Brief must include `primaryFocus`.',
          path: 'directorBrief.primaryFocus',
        ),
      );
    }
    if (rhythm.isEmpty) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Director Brief must include `rhythm`.',
          path: 'directorBrief.rhythm',
        ),
      );
    }
    if (!_allowedAspects.contains(aspect)) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Director Brief aspect `$aspect` is not supported.',
          path: 'directorBrief.aspect',
        ),
      );
    }
    if (!_allowedDurationIntents.contains(durationIntent)) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Director Brief duration intent `$durationIntent` is not supported.',
          path: 'directorBrief.durationIntent',
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
    if (primaryCount > 1) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Director Brief defines multiple primary elements. Keep a single focal hierarchy.',
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

    final duplicateSignatures = <String>{};
    final seenSignatures = <String>{};
    for (final element in elements) {
      final allowDuplicate = element.properties['allowDuplicate'] == true;
      if (allowDuplicate) {
        continue;
      }
      final signature = '${_normalize(element.kind)}|'
          '${_normalize(element.importance)}|'
          '${_normalize(element.text ?? '')}|'
          '${_normalize(element.motionHint ?? '')}';
      if (!seenSignatures.add(signature)) {
        duplicateSignatures.add(signature);
      }
    }
    if (duplicateSignatures.isNotEmpty) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Director Brief contains duplicated elements without explicit allowDuplicate=true.',
          path: 'directorBrief.elements',
        ),
      );
    }

    for (final element in elements) {
      if (_normalize(element.kind) != 'featurecardgroup') {
        continue;
      }
      final isPrimary = _normalize(element.importance) == 'primary';
      if (!isPrimary || element.cards.length < 4) {
        continue;
      }
      final primaryCardIndex = _readInt(element.properties['primaryCardIndex']);
      if (primaryCardIndex == null ||
          primaryCardIndex < 0 ||
          primaryCardIndex >= element.cards.length) {
        issues.add(
          const ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Primary feature-card groups require an explicit `primaryCardIndex` hierarchy.',
            path: 'directorBrief.elements.properties.primaryCardIndex',
          ),
        );
      }
    }

    final moodToken = _normalize(mood);
    final calmMood = moodToken.contains('luxury') ||
        moodToken.contains('minimal') ||
        moodToken.contains('calm');
    final energeticMotionCount = elements.where((element) {
      final hint = _normalize(element.motionHint ?? '');
      if (hint.isEmpty) {
        return false;
      }
      return _highEnergyMotionTokens.any(hint.contains);
    }).length;
    if (calmMood && energeticMotionCount > 0) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Director Brief mood is calm/luxury/minimal but motion hints are high-energy.',
          path: 'directorBrief.elements.motionHint',
        ),
      );
    }
    final hasPlayfulBrand = elements.any((element) {
      final token = (element.brandToken ?? '').trim().toLowerCase();
      return _playfulBrands.contains(token);
    });
    if (calmMood && hasPlayfulBrand && energeticMotionCount > 0) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Director Brief combines playful social brands with calm luxury motion intent without reconciliation.',
          path: 'directorBrief.elements.brandToken',
        ),
      );
    }

    final brief = SceneDirectorBrief(
      intent: intent ?? '',
      audience: audience.isEmpty ? 'general' : audience,
      mood: mood.isEmpty ? 'neutral professional' : mood,
      primaryFocus: primaryFocus.isEmpty ? 'primary element' : primaryFocus,
      rhythm: rhythm.isEmpty ? 'intro hold outro' : rhythm,
      aspect: aspect.isEmpty ? r'$canvas.vertical9x16' : aspect,
      durationIntent:
          durationIntent.isEmpty ? r'$duration.medium' : durationIntent,
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

  int? _readInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw.trim());
    }
    return null;
  }
}
