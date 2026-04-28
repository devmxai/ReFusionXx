import '../models/refusion_motion_director_models.dart';
import '../models/refusion_scene_program_models.dart';

class ReFusionMotionDirectorSceneProgramAlignmentResult {
  ReFusionMotionDirectorSceneProgramAlignmentResult({
    required List<ReFusionMotionDirectorIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionMotionDirectorIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
      );
}

class ReFusionMotionDirectorSceneProgramAlignmentLinter {
  const ReFusionMotionDirectorSceneProgramAlignmentLinter();

  ReFusionMotionDirectorSceneProgramAlignmentResult lint({
    required ReFusionMotionDirectorPlan plan,
    required ReFusionSceneProgram program,
  }) {
    final issues = <ReFusionMotionDirectorIssue>[];
    final index = _SceneProgramTargetIndex(program);
    for (var indexInPlan = 0;
        indexInPlan < plan.components.length;
        indexInPlan += 1) {
      final component = plan.components[indexInPlan];
      if (!index.hasAnyTarget(_targetKeysFor(component))) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Director component `${component.id}` is not represented by any Scene Program layer or element.',
            path: 'components[$indexInPlan]',
          ),
        );
      }
    }

    final componentById = <String, ReFusionMotionDirectorComponent>{
      for (final component in plan.components) component.id: component,
    };
    for (var primitiveIndex = 0;
        primitiveIndex < plan.primitives.length;
        primitiveIndex += 1) {
      final primitive = plan.primitives[primitiveIndex];
      final component = componentById[primitive.targetComponentId];
      if (component == null) {
        continue;
      }
      final expectedProperty = _propertyForPrimitive(primitive, component);
      if (expectedProperty == null) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.warning,
            message:
                'Director primitive `${primitive.id}` has no mappable Scene Program property.',
            path: 'primitives[$primitiveIndex]',
          ),
        );
        continue;
      }
      if (!index.hasChannelForTarget(
        targetKeys: _targetKeysFor(component),
        property: expectedProperty,
      )) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Director primitive `${primitive.id}` expects `$expectedProperty` animation on `${component.id}`, but the Scene Program does not include that channel.',
            path: 'primitives[$primitiveIndex]',
          ),
        );
      }
    }

    return ReFusionMotionDirectorSceneProgramAlignmentResult(issues: issues);
  }

  Set<String> _targetKeysFor(ReFusionMotionDirectorComponent component) {
    return <String>{
      component.id,
      '${component.id}-layer',
      '${component.id}_layer',
      if (component.layerId != null) component.layerId!,
      if (component.elementId != null) component.elementId!,
    }.map(_normalizeToken).where((value) => value.isNotEmpty).toSet();
  }

  String? _propertyForPrimitive(
    ReFusionMotionDirectorPrimitive primitive,
    ReFusionMotionDirectorComponent component,
  ) {
    final explicit = primitive.property?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final kind = _normalizeToken(primitive.kind);
    if (kind == 'typewriter' || kind == 'typing' || kind == 'letterreveal') {
      return 'typewriterProgress';
    }
    if (kind == 'enter' || kind == 'fade' || kind == 'opacity') {
      return 'opacity';
    }
    if (kind == 'move' || kind == 'slide') {
      return 'position';
    }
    if (kind == 'scale' || kind == 'press' || kind == 'cover') {
      return 'scale';
    }
    if (kind == 'widthgrow' || kind == 'linegrow') {
      return 'width';
    }
    if (_normalizeToken(component.role).contains('typewriter')) {
      return 'typewriterProgress';
    }
    return null;
  }

  String _normalizeToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}

class _SceneProgramTargetIndex {
  _SceneProgramTargetIndex(ReFusionSceneProgram program) {
    for (final layer in program.layers) {
      final layerKey = _normalizeToken(layer.id);
      _targets.add(layerKey);
      _channelsByTarget.putIfAbsent(layerKey, () => <String>{}).addAll(
          layer.channels.map((channel) => _propertyKey(channel.property)));
      for (final channel in layer.channels) {
        final targetKey = _normalizeToken(channel.target);
        _targets.add(targetKey);
        _channelsByTarget
            .putIfAbsent(targetKey, () => <String>{})
            .add(_propertyKey(channel.property));
      }
      if (layer.name != null) {
        _targets.add(_normalizeToken(layer.name!));
      }
      for (final element in layer.elements) {
        final elementKey = _normalizeToken(element.id);
        _targets.add(elementKey);
        _channelsByTarget.putIfAbsent(elementKey, () => <String>{}).addAll(
              element.channels.map((channel) => _propertyKey(channel.property)),
            );
        for (final channel in element.channels) {
          final targetKey = _normalizeToken(channel.target);
          if (targetKey.isEmpty) {
            continue;
          }
          _targets.add(targetKey);
          _channelsByTarget
              .putIfAbsent(targetKey, () => <String>{})
              .add(_propertyKey(channel.property));
        }
        if (element.name != null) {
          _targets.add(_normalizeToken(element.name!));
        }
      }
    }
  }

  final Set<String> _targets = <String>{};
  final Map<String, Set<String>> _channelsByTarget = <String, Set<String>>{};

  bool hasAnyTarget(Set<String> targetKeys) {
    return targetKeys.any(_targets.contains);
  }

  bool hasChannelForTarget({
    required Set<String> targetKeys,
    required String property,
  }) {
    final expected = _propertyAliases(property);
    for (final targetKey in targetKeys) {
      final properties = _channelsByTarget[targetKey];
      if (properties == null) {
        continue;
      }
      if (properties.any(expected.contains)) {
        return true;
      }
    }
    return false;
  }

  Set<String> _propertyAliases(String property) {
    final key = _propertyKey(property);
    if (key == 'typewriterprogress' ||
        key == 'typingprogress' ||
        key == 'letterrevealprogress' ||
        key == 'letterreveal') {
      return const <String>{
        'typewriterprogress',
        'typingprogress',
        'letterrevealprogress',
        'letterreveal',
        'reveal',
      };
    }
    if (key == 'position') {
      return const <String>{'position', 'positionx', 'positiony'};
    }
    if (key == 'scale') {
      return const <String>{'scale', 'scalex', 'scaley'};
    }
    return <String>{key};
  }

  String _propertyKey(String value) => _normalizeToken(value);

  String _normalizeToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
