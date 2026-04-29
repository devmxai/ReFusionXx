import '../models/refusion_scene_program_models.dart';

class SceneProgramLayoutContractResult {
  SceneProgramLayoutContractResult({
    required List<ReFusionSceneProgramIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneProgramLayoutContractValidator {
  const SceneProgramLayoutContractValidator();

  SceneProgramLayoutContractResult validate(ReFusionSceneProgram program) {
    final issues = <ReFusionSceneProgramIssue>[];
    final records = <String, _LayoutElementRecord>{};
    final duplicateIds = <String>{};

    for (var layerIndex = 0; layerIndex < program.layers.length; layerIndex++) {
      final layer = program.layers[layerIndex];
      for (var elementIndex = 0;
          elementIndex < layer.elements.length;
          elementIndex++) {
        final element = layer.elements[elementIndex];
        final path = 'layers[$layerIndex].elements[$elementIndex]';
        final existing = records[element.id];
        if (existing != null) {
          duplicateIds.add(element.id);
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message:
                  'Element id `${element.id}` must be unique before it can participate in layout or parent groups.',
              path: path,
            ),
          );
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message:
                  'Element id `${element.id}` is duplicated by another element.',
              path: existing.path,
            ),
          );
        } else {
          records[element.id] = _LayoutElementRecord(
            element: element,
            layer: layer,
            path: path,
          );
        }
      }
    }

    if (records.isEmpty) {
      return SceneProgramLayoutContractResult(issues: issues);
    }

    final parentByChild = <String, String>{};
    for (final record in records.values) {
      final parentId = _parentIdFor(record.element);
      if (parentId == null || parentId.isEmpty) {
        continue;
      }
      if (duplicateIds.contains(record.element.id)) {
        continue;
      }
      if (parentId == record.element.id) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Element `${record.element.id}` cannot be its own layout parent.',
            path: '${record.path}.properties.parentId',
          ),
        );
        continue;
      }
      final parent = records[parentId];
      if (parent == null) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Layout parent `$parentId` for element `${record.element.id}` does not exist in this Scene Program.',
            path: '${record.path}.properties.parentId',
          ),
        );
        continue;
      }
      parentByChild[record.element.id] = parentId;
      _lintChildLifetimeInsideParent(
        child: record,
        parent: parent,
        issues: issues,
      );
      _lintParentRoleHint(
        child: record,
        parent: parent,
        issues: issues,
      );
    }

    _lintParentCycles(parentByChild, records, issues);

    return SceneProgramLayoutContractResult(issues: issues);
  }

  void _lintChildLifetimeInsideParent({
    required _LayoutElementRecord child,
    required _LayoutElementRecord parent,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final childStart = child.layer.startMs;
    final childEnd = child.layer.startMs + child.layer.durationMs;
    final parentStart = parent.layer.startMs;
    final parentEnd = parent.layer.startMs + parent.layer.durationMs;
    if (childStart >= parentStart && childEnd <= parentEnd) {
      return;
    }
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.error,
        message:
            'Child element `${child.element.id}` lifetime must stay inside parent `${parent.element.id}` lifetime.',
        path: child.path,
      ),
    );
  }

  void _lintParentRoleHint({
    required _LayoutElementRecord child,
    required _LayoutElementRecord parent,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final role = _layoutRoleFor(parent.element);
    if (role == null || role.isEmpty) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.warning,
          message:
              'Parent element `${parent.element.id}` should declare `layoutRole: "container"` or `layoutRole: "group"` for inspectable UI composition.',
          path: parent.path,
        ),
      );
      return;
    }
    final normalizedRole = _normalizeToken(role);
    if (normalizedRole == 'container' || normalizedRole == 'group') {
      return;
    }
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.warning,
        message:
            'Parent element `${parent.element.id}` uses layout role `$role`; prefer `container` or `group` for editable child composition.',
        path: parent.path,
      ),
    );
  }

  void _lintParentCycles(
    Map<String, String> parentByChild,
    Map<String, _LayoutElementRecord> records,
    List<ReFusionSceneProgramIssue> issues,
  ) {
    for (final childId in parentByChild.keys) {
      final seen = <String>{};
      var cursor = childId;
      while (true) {
        if (!seen.add(cursor)) {
          final record = records[childId];
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message:
                  'Layout parent chain for element `$childId` contains a cycle.',
              path:
                  record == null ? null : '${record.path}.properties.parentId',
            ),
          );
          break;
        }
        final next = parentByChild[cursor];
        if (next == null) {
          break;
        }
        cursor = next;
      }
    }
  }

  String? _parentIdFor(ReFusionSceneProgramElement element) {
    final direct = _propertyByNormalizedKey(element.properties, 'parentId') ??
        _propertyByNormalizedKey(element.properties, 'parent') ??
        _propertyByNormalizedKey(element.properties, 'containerId') ??
        _propertyByNormalizedKey(element.properties, 'parentGroup');
    final parent = _stringOrNull(direct);
    if (parent != null) {
      return parent;
    }
    final layout = _propertyByNormalizedKey(element.properties, 'layout');
    if (layout is Map) {
      return _stringOrNull(
            _propertyByNormalizedKey(
              layout.cast<String, Object?>(),
              'parentId',
            ),
          ) ??
          _stringOrNull(
            _propertyByNormalizedKey(
              layout.cast<String, Object?>(),
              'parent',
            ),
          ) ??
          _stringOrNull(
            _propertyByNormalizedKey(
              layout.cast<String, Object?>(),
              'containerId',
            ),
          );
    }
    return null;
  }

  String? _layoutRoleFor(ReFusionSceneProgramElement element) {
    final direct = _propertyByNormalizedKey(element.properties, 'layoutRole') ??
        _propertyByNormalizedKey(element.properties, 'role');
    final role = _stringOrNull(direct);
    if (role != null) {
      return role;
    }
    final layout = _propertyByNormalizedKey(element.properties, 'layout');
    if (layout is Map) {
      return _stringOrNull(
            _propertyByNormalizedKey(
              layout.cast<String, Object?>(),
              'layoutRole',
            ),
          ) ??
          _stringOrNull(
            _propertyByNormalizedKey(
              layout.cast<String, Object?>(),
              'role',
            ),
          );
    }
    return null;
  }

  Object? _propertyByNormalizedKey(
    Map<String, Object?> properties,
    String key,
  ) {
    final normalizedKey = _normalizeToken(key);
    for (final entry in properties.entries) {
      if (_normalizeToken(entry.key) == normalizedKey) {
        return entry.value;
      }
    }
    return null;
  }

  String? _stringOrNull(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _normalizeToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}

class _LayoutElementRecord {
  const _LayoutElementRecord({
    required this.element,
    required this.layer,
    required this.path,
  });

  final ReFusionSceneProgramElement element;
  final ReFusionSceneProgramLayer layer;
  final String path;
}
