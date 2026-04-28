import '../models/refusion_motion_director_models.dart';

class ReFusionMotionDirectorPlanImportResult {
  ReFusionMotionDirectorPlanImportResult({
    required List<ReFusionMotionDirectorIssue> issues,
    this.plan,
  }) : issues = List.unmodifiable(issues);

  final ReFusionMotionDirectorPlan? plan;
  final List<ReFusionMotionDirectorIssue> issues;

  bool get isValid =>
      plan != null &&
      !issues.any(
        (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
      );
}

class ReFusionMotionDirectorPlanImportService {
  const ReFusionMotionDirectorPlanImportService();

  ReFusionMotionDirectorPlanImportResult importFromJson(Object? raw) {
    final issues = <ReFusionMotionDirectorIssue>[];
    if (raw is! Map) {
      return ReFusionMotionDirectorPlanImportResult(
        issues: const <ReFusionMotionDirectorIssue>[
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message: 'Director plan must be a JSON object.',
            path: 'directorPlan',
          ),
        ],
      );
    }
    final map = raw.cast<String, Object?>();
    final schemaVersion =
        _readString(map, const <String>['schemaVersion', 'version']) ??
            ReFusionMotionDirectorPlan.currentSchemaVersion;
    final durationMs = _readPositiveInt(
      map,
      'durationMs',
      fallback: 3600,
      issues: issues,
      path: 'durationMs',
    );
    final frameRate = _readPositiveDouble(
      map,
      'frameRate',
      fallback: 30,
      issues: issues,
      path: 'frameRate',
    );
    final plan = ReFusionMotionDirectorPlan(
      schemaVersion: schemaVersion,
      name: _readString(map, const <String>['name', 'title']) ??
          'Generated Director Plan',
      durationMs: durationMs,
      frameRate: frameRate,
      canvasWidth: _readPositiveInt(
        map,
        'canvasWidth',
        fallback: 1080,
        issues: issues,
        path: 'canvasWidth',
      ),
      canvasHeight: _readPositiveInt(
        map,
        'canvasHeight',
        fallback: 1920,
        issues: issues,
        path: 'canvasHeight',
      ),
      beats: _readBeats(map['beats'], issues),
      components: _readComponents(map['components'], issues),
      primitives: _readPrimitives(map['primitives'], issues),
    );
    return ReFusionMotionDirectorPlanImportResult(
      plan: plan,
      issues: issues,
    );
  }

  List<ReFusionMotionDirectorBeat> _readBeats(
    Object? raw,
    List<ReFusionMotionDirectorIssue> issues,
  ) {
    if (raw is! List) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message: 'Director plan beats must be a list.',
          path: 'beats',
        ),
      );
      return const <ReFusionMotionDirectorBeat>[];
    }
    final beats = <ReFusionMotionDirectorBeat>[];
    for (var index = 0; index < raw.length; index += 1) {
      final value = raw[index];
      final path = 'beats[$index]';
      if (value is! Map) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message: 'Director beat must be an object.',
            path: path,
          ),
        );
        continue;
      }
      final map = value.cast<String, Object?>();
      beats.add(
        ReFusionMotionDirectorBeat(
          id: _readString(map, const <String>['id']) ?? 'beat-$index',
          label: _readString(map, const <String>['label', 'name']) ??
              'Beat ${index + 1}',
          startMs: _readInt(map, 'startMs', fallback: 0),
          endMs: _readInt(map, 'endMs', fallback: 0),
          intent:
              _readString(map, const <String>['intent', 'description']) ?? '',
          componentRefs: _readStringList(map['componentRefs']),
        ),
      );
    }
    return beats;
  }

  List<ReFusionMotionDirectorComponent> _readComponents(
    Object? raw,
    List<ReFusionMotionDirectorIssue> issues,
  ) {
    if (raw is! List) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message: 'Director plan components must be a list.',
          path: 'components',
        ),
      );
      return const <ReFusionMotionDirectorComponent>[];
    }
    final components = <ReFusionMotionDirectorComponent>[];
    for (var index = 0; index < raw.length; index += 1) {
      final value = raw[index];
      final path = 'components[$index]';
      if (value is! Map) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message: 'Director component must be an object.',
            path: path,
          ),
        );
        continue;
      }
      final map = value.cast<String, Object?>();
      components.add(
        ReFusionMotionDirectorComponent(
          id: _readString(map, const <String>['id']) ?? 'component-$index',
          role: _readString(map, const <String>['role', 'kind']) ?? '',
          label: _readString(map, const <String>['label', 'name']) ??
              'Component ${index + 1}',
          layerId: _readString(map, const <String>['layerId']),
          elementId: _readString(map, const <String>['elementId']),
          properties: _readObjectMap(map['properties']),
        ),
      );
    }
    return components;
  }

  List<ReFusionMotionDirectorPrimitive> _readPrimitives(
    Object? raw,
    List<ReFusionMotionDirectorIssue> issues,
  ) {
    if (raw is! List) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message: 'Director plan primitives must be a list.',
          path: 'primitives',
        ),
      );
      return const <ReFusionMotionDirectorPrimitive>[];
    }
    final primitives = <ReFusionMotionDirectorPrimitive>[];
    for (var index = 0; index < raw.length; index += 1) {
      final value = raw[index];
      final path = 'primitives[$index]';
      if (value is! Map) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message: 'Director primitive must be an object.',
            path: path,
          ),
        );
        continue;
      }
      final map = value.cast<String, Object?>();
      primitives.add(
        ReFusionMotionDirectorPrimitive(
          id: _readString(map, const <String>['id']) ?? 'primitive-$index',
          beatId: _readString(map, const <String>['beatId']) ?? '',
          targetComponentId:
              _readString(map, const <String>['targetComponentId', 'target']) ??
                  '',
          kind: _readString(map, const <String>['kind', 'type']) ?? '',
          property: _readString(map, const <String>['property']),
          startMs: _readInt(map, 'startMs', fallback: 0),
          endMs: _readInt(map, 'endMs', fallback: 0),
          fromValue: map['fromValue'] ?? map['from'],
          toValue: map['toValue'] ?? map['to'],
          easing: _readString(map, const <String>['easing']) ?? 'linear',
          note: _readString(map, const <String>['note']),
        ),
      );
    }
    return primitives;
  }

  String? _readString(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  int _readPositiveInt(
    Map<String, Object?> map,
    String key, {
    required int fallback,
    required List<ReFusionMotionDirectorIssue> issues,
    required String path,
  }) {
    final value = map[key];
    if (value is num && value > 0) {
      return value.round();
    }
    if (value != null) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.warning,
          message: 'Director `$key` was not a positive number; using fallback.',
          path: path,
        ),
      );
    }
    return fallback;
  }

  double _readPositiveDouble(
    Map<String, Object?> map,
    String key, {
    required double fallback,
    required List<ReFusionMotionDirectorIssue> issues,
    required String path,
  }) {
    final value = map[key];
    if (value is num && value > 0) {
      return value.toDouble();
    }
    if (value != null) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.warning,
          message: 'Director `$key` was not a positive number; using fallback.',
          path: path,
        ),
      );
    }
    return fallback;
  }

  int _readInt(Map<String, Object?> map, String key, {required int fallback}) {
    final value = map[key];
    if (value is num) {
      return value.round();
    }
    return fallback;
  }

  List<String> _readStringList(Object? raw) {
    if (raw is! List) {
      return const <String>[];
    }
    return raw
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, Object?> _readObjectMap(Object? raw) {
    if (raw is Map) {
      return raw.cast<String, Object?>();
    }
    return const <String, Object?>{};
  }
}
