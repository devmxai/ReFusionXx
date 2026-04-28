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
    final index = _SceneProgramTargetIndex(program, plan: plan);
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
    final keys = <String>{
      component.id,
      '${component.id}-layer',
      '${component.id}_layer',
      if (component.layerId != null) component.layerId!,
      if (component.elementId != null) component.elementId!,
    }.map(_normalizeToken).where((value) => value.isNotEmpty).toSet();
    if (_isBackgroundComponent(component)) {
      keys.addAll(_SceneProgramTargetIndex.backgroundAliases);
    }
    return keys;
  }

  bool _isBackgroundComponent(ReFusionMotionDirectorComponent component) {
    final role = _normalizeToken(component.role);
    final id = _normalizeToken(component.id);
    final label = _normalizeToken(component.label);
    return role.contains('background') ||
        role.contains('canvas') ||
        role.contains('backdrop') ||
        id == 'bg' ||
        id.contains('background') ||
        id.contains('canvas') ||
        id.contains('backdrop') ||
        label.contains('background') ||
        label.contains('canvas') ||
        label.contains('backdrop');
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
  _SceneProgramTargetIndex(
    ReFusionSceneProgram program, {
    required ReFusionMotionDirectorPlan plan,
  }) {
    for (final layer in program.layers) {
      final layerKey = _normalizeToken(layer.id);
      final layerChannelProperties =
          layer.channels.map((channel) => _propertyKey(channel.property));
      _addTargetWithChannels(layerKey, layerChannelProperties);
      if (layer.name != null) {
        _addTargetWithChannels(
          _normalizeToken(layer.name!),
          layerChannelProperties,
        );
      }
      if (_isLikelyBackgroundLayer(layer)) {
        _addBackgroundAliases(layerChannelProperties);
      }
      for (final channel in layer.channels) {
        final targetKey = _normalizeToken(channel.target);
        _addTargetWithChannels(
          targetKey,
          <String>{_propertyKey(channel.property)},
        );
      }
      for (final element in layer.elements) {
        final elementKey = _normalizeToken(element.id);
        final elementChannelProperties =
            element.channels.map((channel) => _propertyKey(channel.property));
        _addTargetWithChannels(elementKey, elementChannelProperties);
        if (element.name != null) {
          _addTargetWithChannels(
            _normalizeToken(element.name!),
            elementChannelProperties,
          );
        }
        if (_isLikelyBackgroundElement(
          element,
          canvasWidth: plan.canvasWidth,
          canvasHeight: plan.canvasHeight,
        )) {
          _addBackgroundAliases(elementChannelProperties);
        }
        for (final channel in element.channels) {
          final targetKey = _normalizeToken(channel.target);
          if (targetKey.isEmpty) {
            continue;
          }
          _addTargetWithChannels(
            targetKey,
            <String>{_propertyKey(channel.property)},
          );
        }
      }
    }
  }

  static const Set<String> backgroundAliases = <String>{
    'background',
    'backgroundlayer',
    'backgroundsolid',
    'backgroundfill',
    'bg',
    'bglayer',
    'bgsolid',
    'bgfill',
    'canvas',
    'canvaslayer',
    'canvassolid',
    'canvasfill',
    'backdrop',
    'backdroplayer',
    'backdropsolid',
  };

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

  void _addTargetWithChannels(
    String targetKey,
    Iterable<String> properties,
  ) {
    if (targetKey.isEmpty) {
      return;
    }
    _targets.add(targetKey);
    final normalizedProperties =
        properties.where((property) => property.isNotEmpty);
    _channelsByTarget
        .putIfAbsent(targetKey, () => <String>{})
        .addAll(normalizedProperties);
  }

  void _addBackgroundAliases(Iterable<String> properties) {
    for (final alias in backgroundAliases) {
      _addTargetWithChannels(alias, properties);
    }
  }

  bool _isLikelyBackgroundLayer(ReFusionSceneProgramLayer layer) {
    return _containsBackgroundToken(layer.id) ||
        (layer.name != null && _containsBackgroundToken(layer.name!));
  }

  bool _isLikelyBackgroundElement(
    ReFusionSceneProgramElement element, {
    required int canvasWidth,
    required int canvasHeight,
  }) {
    return _containsBackgroundToken(element.id) ||
        (element.name != null && _containsBackgroundToken(element.name!)) ||
        _isFullCanvasSolid(
          element,
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
        );
  }

  bool _containsBackgroundToken(String value) {
    final key = _normalizeToken(value);
    return key == 'bg' ||
        key.startsWith('bg') ||
        key.endsWith('bg') ||
        key.contains('background') ||
        key.contains('canvas') ||
        key.contains('backdrop');
  }

  bool _isFullCanvasSolid(
    ReFusionSceneProgramElement element, {
    required int canvasWidth,
    required int canvasHeight,
  }) {
    final kind = _normalizeToken(element.kind);
    final shapeKind =
        _normalizeToken('${element.properties['shapeKind'] ?? ''}');
    if (kind != 'solid' &&
        shapeKind != 'solid' &&
        shapeKind != 'rectangle' &&
        shapeKind != 'rect') {
      return false;
    }
    final width = _readDouble(element.properties['width']);
    final height = _readDouble(element.properties['height']);
    if (width == null || height == null) {
      return false;
    }
    return width >= canvasWidth * 0.9 && height >= canvasHeight * 0.9;
  }

  double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  String _propertyKey(String value) => _normalizeToken(value);

  String _normalizeToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
