import '../models/refusion_motion_director_models.dart';
import '../models/refusion_scene_program_models.dart';

class ProfessionalSceneTimingContractPolicy {
  const ProfessionalSceneTimingContractPolicy({
    this.minimumReadableHoldMs = 360,
    this.minimumCompletionHoldMs = 240,
    this.requireReadableTextHold = true,
    this.requirePrimitiveBeatOwnership = true,
    this.warnSequentialSamePropertyPrimitives = true,
    this.warnFinalMotionWithoutHold = true,
  });

  final int minimumReadableHoldMs;
  final int minimumCompletionHoldMs;
  final bool requireReadableTextHold;
  final bool requirePrimitiveBeatOwnership;
  final bool warnSequentialSamePropertyPrimitives;
  final bool warnFinalMotionWithoutHold;
}

class ProfessionalSceneComponentTiming {
  const ProfessionalSceneComponentTiming({
    required this.componentId,
    required this.startMs,
    required this.endMs,
    required this.hasMotion,
    required this.hasReadableHold,
  });

  final String componentId;
  final int startMs;
  final int endMs;
  final bool hasMotion;
  final bool hasReadableHold;

  int get durationMs => endMs - startMs;
}

class ProfessionalDirectorTimingContractResult {
  ProfessionalDirectorTimingContractResult({
    required List<ReFusionMotionDirectorIssue> issues,
    required List<ProfessionalSceneComponentTiming> componentTimings,
  })  : issues = List.unmodifiable(issues),
        componentTimings = List.unmodifiable(componentTimings);

  final List<ReFusionMotionDirectorIssue> issues;
  final List<ProfessionalSceneComponentTiming> componentTimings;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
      );
}

class ProfessionalSceneProgramTimingContractResult {
  ProfessionalSceneProgramTimingContractResult({
    required List<ReFusionSceneProgramIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class ProfessionalSceneTimingContractIssueFormatter {
  const ProfessionalSceneTimingContractIssueFormatter();

  String formatSceneProgramIssues(
    List<ReFusionSceneProgramIssue> issues, {
    int maxIssues = 3,
  }) {
    final errors = issues
        .where(
          (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
        )
        .take(maxIssues)
        .toList(growable: false);
    if (errors.isEmpty) {
      return '';
    }
    return errors.map(_formatSceneProgramIssue).join(' ');
  }

  String formatDirectorIssues(
    List<ReFusionMotionDirectorIssue> issues, {
    int maxIssues = 3,
  }) {
    final errors = issues
        .where(
          (issue) =>
              issue.severity == ReFusionMotionDirectorIssueSeverity.error,
        )
        .take(maxIssues)
        .toList(growable: false);
    if (errors.isEmpty) {
      return '';
    }
    return errors.map(_formatDirectorIssue).join(' ');
  }

  String _formatSceneProgramIssue(ReFusionSceneProgramIssue issue) {
    final base = _withPath(issue.path, issue.message);
    final hint = _sceneProgramFixHint(issue.message);
    return hint == null ? base : '$base Fix: $hint';
  }

  String _formatDirectorIssue(ReFusionMotionDirectorIssue issue) {
    final base = _withPath(issue.path, issue.message);
    final hint = _directorFixHint(issue.message);
    return hint == null ? base : '$base Fix: $hint';
  }

  String _withPath(String? path, String message) {
    final normalizedPath = path?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) {
      return message;
    }
    return '$normalizedPath: $message';
  }

  String? _sceneProgramFixHint(String message) {
    final normalized = _normalizeToken(message);
    if (normalized.contains('duplicatesceneprogramchannel')) {
      return 'merge all keyframes for the same target/property into one ordered channel; never emit a second channel for that property.';
    }
    if (normalized.contains('keyframetimemsmustbeinside')) {
      return 'use layer-local timeMs from 0 to layer.durationMs, or extend the owning layer duration before placing that keyframe.';
    }
    if (normalized.contains('keyframesmustbesorted')) {
      return 'sort keyframes by ascending timeMs before returning JSON.';
    }
    if (normalized.contains('channelmustincludekeyframes')) {
      return 'add at least two meaningful keyframes for animated properties, or remove the empty channel entirely.';
    }
    if (normalized.contains('lifetimemuststayinside')) {
      return 'adjust layer startMs/durationMs or increase scene durationMs so the layer fits inside the scene.';
    }
    if (normalized.contains('musthavepositiveduration') ||
        normalized.contains('durationmustbegreaterthanzero')) {
      return 'use a positive duration and ensure end time is after start time.';
    }
    return null;
  }

  String? _directorFixHint(String message) {
    final normalized = _normalizeToken(message);
    if (normalized.contains('readablehold')) {
      return 'add a readable hold beat after text reveal, reference the same component, and keep it at least 360ms.';
    }
    if (normalized.contains('endsatthesceneboundary')) {
      return 'extend durationMs and add a hold after the reveal before the scene ends.';
    }
    if (normalized.contains('overlaponthesametargetproperty')) {
      return 'model this property as one ordered primitive track, or split the overlap into different property groups.';
    }
    if (normalized.contains('mustreferencetargetcomponent')) {
      return 'put the target component id inside the owning beat componentRefs before assigning a primitive to that beat.';
    }
    if (normalized.contains('owningbeat')) {
      return 'move the primitive inside its beat time range or create a beat that exactly owns this motion.';
    }
    if (normalized.contains('muststayinside')) {
      return 'keep every beat and primitive inside the scene duration and inside its owning beat.';
    }
    if (normalized.contains('finalmotionendsatthesceneboundary')) {
      return 'extend scene duration and add a resolve/hold beat after the final motion, or mark the component as a transition/background cover.';
    }
    if (normalized.contains('runsbackward')) {
      return 'typewriter values must progress forward from 0.0 toward 1.0.';
    }
    return null;
  }

  String _normalizeToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}

class ProfessionalSceneTimingContractValidator {
  const ProfessionalSceneTimingContractValidator({
    this.policy = const ProfessionalSceneTimingContractPolicy(),
  });

  final ProfessionalSceneTimingContractPolicy policy;

  ProfessionalDirectorTimingContractResult validateDirectorPlan(
    ReFusionMotionDirectorPlan plan,
  ) {
    final issues = <ReFusionMotionDirectorIssue>[];
    final componentIds =
        plan.components.map((component) => component.id).toSet();
    final componentById = <String, ReFusionMotionDirectorComponent>{
      for (final component in plan.components) component.id: component,
    };
    final beatsByComponent = <String, List<ReFusionMotionDirectorBeat>>{};
    for (final beat in plan.beats) {
      for (final componentRef in beat.componentRefs) {
        beatsByComponent
            .putIfAbsent(componentRef, () => <ReFusionMotionDirectorBeat>[])
            .add(beat);
      }
    }
    final primitivesByComponent =
        <String, List<ReFusionMotionDirectorPrimitive>>{};
    for (final primitive in plan.primitives) {
      primitivesByComponent
          .putIfAbsent(
            primitive.targetComponentId,
            () => <ReFusionMotionDirectorPrimitive>[],
          )
          .add(primitive);
    }

    _lintSamePropertyPrimitiveTracks(plan, issues);
    if (policy.requirePrimitiveBeatOwnership) {
      _lintPrimitiveBeatOwnership(plan, issues);
    }
    if (policy.requireReadableTextHold) {
      _lintReadableTextHolds(
        plan: plan,
        componentById: componentById,
        beatsByComponent: beatsByComponent,
        primitivesByComponent: primitivesByComponent,
        issues: issues,
      );
    }
    if (policy.warnFinalMotionWithoutHold) {
      _lintFinalMotionCompletion(
        plan: plan,
        componentById: componentById,
        beatsByComponent: beatsByComponent,
        primitivesByComponent: primitivesByComponent,
        issues: issues,
      );
    }

    final timings = <ProfessionalSceneComponentTiming>[];
    for (final componentId in componentIds) {
      final beats =
          beatsByComponent[componentId] ?? const <ReFusionMotionDirectorBeat>[];
      final primitives = primitivesByComponent[componentId] ??
          const <ReFusionMotionDirectorPrimitive>[];
      final starts = <int>[
        for (final beat in beats) beat.startMs,
        for (final primitive in primitives) primitive.startMs,
      ];
      final ends = <int>[
        for (final beat in beats) beat.endMs,
        for (final primitive in primitives) primitive.endMs,
      ];
      if (starts.isEmpty || ends.isEmpty) {
        continue;
      }
      timings.add(
        ProfessionalSceneComponentTiming(
          componentId: componentId,
          startMs: starts.reduce((left, right) => left < right ? left : right),
          endMs: ends.reduce((left, right) => left > right ? left : right),
          hasMotion: primitives.isNotEmpty,
          hasReadableHold: _hasReadableHoldAfter(
            componentId: componentId,
            afterMs: primitives.isEmpty
                ? starts.reduce((left, right) => left < right ? left : right)
                : primitives
                    .map((primitive) => primitive.endMs)
                    .reduce((left, right) => left > right ? left : right),
            beatsByComponent: beatsByComponent,
          ),
        ),
      );
    }

    return ProfessionalDirectorTimingContractResult(
      issues: issues,
      componentTimings: timings,
    );
  }

  ProfessionalSceneProgramTimingContractResult validateSceneProgram(
    ReFusionSceneProgram program,
  ) {
    final issues = <ReFusionSceneProgramIssue>[];
    if (program.durationMs <= 0) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Scene duration must be greater than zero.',
          path: 'durationMs',
        ),
      );
    }
    for (var layerIndex = 0;
        layerIndex < program.layers.length;
        layerIndex += 1) {
      final layer = program.layers[layerIndex];
      final layerPath = 'layers[$layerIndex]';
      if (layer.durationMs <= 0) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Layer `${layer.id}` must have positive duration.',
            path: '$layerPath.durationMs',
          ),
        );
      }
      if (layer.startMs < 0 ||
          layer.startMs + layer.durationMs > program.durationMs) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Layer `${layer.id}` lifetime must stay inside the scene duration.',
            path: layerPath,
          ),
        );
      }
      _lintSceneProgramChannels(
        ownerChannels: layer.channels,
        ownerPath: '$layerPath.channels',
        ownerDurationMs: layer.durationMs,
        issues: issues,
      );
      for (var elementIndex = 0;
          elementIndex < layer.elements.length;
          elementIndex += 1) {
        final element = layer.elements[elementIndex];
        _lintSceneProgramChannels(
          ownerChannels: element.channels,
          ownerPath: '$layerPath.elements[$elementIndex].channels',
          ownerDurationMs: layer.durationMs,
          issues: issues,
        );
      }
    }
    return ProfessionalSceneProgramTimingContractResult(issues: issues);
  }

  void _lintSamePropertyPrimitiveTracks(
    ReFusionMotionDirectorPlan plan,
    List<ReFusionMotionDirectorIssue> issues,
  ) {
    final buckets = <String, List<ReFusionMotionDirectorPrimitive>>{};
    for (final primitive in plan.primitives) {
      final propertyGroup = _propertyGroupForPrimitive(primitive);
      if (propertyGroup == null) {
        continue;
      }
      final key = '${primitive.targetComponentId}::$propertyGroup';
      buckets
          .putIfAbsent(key, () => <ReFusionMotionDirectorPrimitive>[])
          .add(primitive);
    }
    for (final entry in buckets.entries) {
      final primitives = List<ReFusionMotionDirectorPrimitive>.from(entry.value)
        ..sort((left, right) => left.startMs.compareTo(right.startMs));
      if (primitives.length < 2) {
        continue;
      }
      for (var index = 1; index < primitives.length; index += 1) {
        final previous = primitives[index - 1];
        final current = primitives[index];
        if (previous.endMs > current.startMs) {
          issues.add(
            ReFusionMotionDirectorIssue(
              severity: ReFusionMotionDirectorIssueSeverity.error,
              message:
                  'Primitives `${previous.id}` and `${current.id}` overlap on the same target/property. Model this as one ordered track or an explicit disjoint-property handoff.',
              path: 'primitives',
            ),
          );
          continue;
        }
      }
      if (policy.warnSequentialSamePropertyPrimitives) {
        issues.add(
          const ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.warning,
            message:
                'Multiple sequential primitives target the same component/property. The compiler will merge them into one ordered channel before lowering.',
            path: 'primitives',
          ),
        );
      }
    }
  }

  void _lintPrimitiveBeatOwnership(
    ReFusionMotionDirectorPlan plan,
    List<ReFusionMotionDirectorIssue> issues,
  ) {
    final beatById = <String, ReFusionMotionDirectorBeat>{
      for (final beat in plan.beats) beat.id: beat,
    };
    for (final primitive in plan.primitives) {
      final beat = beatById[primitive.beatId];
      if (beat == null) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Primitive `${primitive.id}` references missing owning beat `${primitive.beatId}`.',
            path: 'primitives.${primitive.id}.beatId',
          ),
        );
        continue;
      }
      if (!beat.componentRefs.contains(primitive.targetComponentId)) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Owning beat `${beat.id}` must reference target component `${primitive.targetComponentId}` before primitive `${primitive.id}` can animate it.',
            path: 'beats.${beat.id}.componentRefs',
          ),
        );
      }
      if (primitive.startMs < beat.startMs || primitive.endMs > beat.endMs) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Primitive `${primitive.id}` must stay inside owning beat `${beat.id}` time range.',
            path: 'primitives.${primitive.id}',
          ),
        );
      }
    }
  }

  void _lintFinalMotionCompletion({
    required ReFusionMotionDirectorPlan plan,
    required Map<String, ReFusionMotionDirectorComponent> componentById,
    required Map<String, List<ReFusionMotionDirectorBeat>> beatsByComponent,
    required Map<String, List<ReFusionMotionDirectorPrimitive>>
        primitivesByComponent,
    required List<ReFusionMotionDirectorIssue> issues,
  }) {
    for (final entry in primitivesByComponent.entries) {
      final component = componentById[entry.key];
      if (component == null || _isCompletionExemptComponent(component)) {
        continue;
      }
      if (entry.value.isEmpty) {
        continue;
      }
      final finalPrimitive = entry.value.reduce(
        (left, right) => left.endMs >= right.endMs ? left : right,
      );
      if (finalPrimitive.endMs < plan.durationMs) {
        continue;
      }
      if (_hasCompletionBeatAfter(
        componentId: component.id,
        afterMs: finalPrimitive.endMs,
        beatsByComponent: beatsByComponent,
      )) {
        continue;
      }
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.warning,
          message:
              'Component `${component.id}` final motion ends at the scene boundary. Add a resolve or hold beat so the final frame is intentional.',
          path: 'components.${component.id}',
        ),
      );
    }
  }

  void _lintReadableTextHolds({
    required ReFusionMotionDirectorPlan plan,
    required Map<String, ReFusionMotionDirectorComponent> componentById,
    required Map<String, List<ReFusionMotionDirectorBeat>> beatsByComponent,
    required Map<String, List<ReFusionMotionDirectorPrimitive>>
        primitivesByComponent,
    required List<ReFusionMotionDirectorIssue> issues,
  }) {
    for (final entry in primitivesByComponent.entries) {
      final component = componentById[entry.key];
      if (component == null || !_isReadableTextComponent(component)) {
        continue;
      }
      final revealPrimitives = entry.value.where(_isTextRevealPrimitive);
      for (final primitive in revealPrimitives) {
        if (primitive.endMs >= plan.durationMs) {
          issues.add(
            ReFusionMotionDirectorIssue(
              severity: ReFusionMotionDirectorIssueSeverity.error,
              message:
                  'Text reveal primitive `${primitive.id}` ends at the scene boundary. Add a readable hold after the text reveal.',
              path: 'primitives.${primitive.id}',
            ),
          );
          continue;
        }
        if (!_hasReadableHoldAfter(
          componentId: component.id,
          afterMs: primitive.endMs,
          beatsByComponent: beatsByComponent,
        )) {
          issues.add(
            ReFusionMotionDirectorIssue(
              severity: ReFusionMotionDirectorIssueSeverity.error,
              message:
                  'Text component `${component.id}` must have an explicit readable hold beat of at least ${policy.minimumReadableHoldMs}ms after reveal primitive `${primitive.id}`.',
              path: 'components.${component.id}',
            ),
          );
        }
      }
    }
  }

  bool _hasReadableHoldAfter({
    required String componentId,
    required int afterMs,
    required Map<String, List<ReFusionMotionDirectorBeat>> beatsByComponent,
  }) {
    final beats =
        beatsByComponent[componentId] ?? const <ReFusionMotionDirectorBeat>[];
    for (final beat in beats) {
      if (beat.startMs < afterMs) {
        continue;
      }
      if (beat.durationMs < policy.minimumReadableHoldMs) {
        continue;
      }
      if (_isReadableHoldBeat(beat)) {
        return true;
      }
    }
    return false;
  }

  bool _hasCompletionBeatAfter({
    required String componentId,
    required int afterMs,
    required Map<String, List<ReFusionMotionDirectorBeat>> beatsByComponent,
  }) {
    final beats =
        beatsByComponent[componentId] ?? const <ReFusionMotionDirectorBeat>[];
    for (final beat in beats) {
      if (beat.startMs < afterMs) {
        continue;
      }
      if (beat.durationMs < policy.minimumCompletionHoldMs) {
        continue;
      }
      final text = _normalizeToken('${beat.label} ${beat.intent}');
      if (text.contains('resolve') ||
          text.contains('hold') ||
          text.contains('settle') ||
          text.contains('final') ||
          text.contains('complete')) {
        return true;
      }
    }
    return false;
  }

  bool _isReadableTextComponent(ReFusionMotionDirectorComponent component) {
    final role = _normalizeToken(component.role);
    return role.contains('text') ||
        role.contains('title') ||
        role.contains('label') ||
        role.contains('caption');
  }

  bool _isTextRevealPrimitive(ReFusionMotionDirectorPrimitive primitive) {
    final propertyGroup = _propertyGroupForPrimitive(primitive);
    final kind = _normalizeToken(primitive.kind);
    return propertyGroup == 'typewriterprogress' ||
        propertyGroup == 'reveal' ||
        kind.contains('typewriter') ||
        kind.contains('typing') ||
        kind.contains('reveal');
  }

  bool _isReadableHoldBeat(ReFusionMotionDirectorBeat beat) {
    final text = _normalizeToken('${beat.label} ${beat.intent}');
    return text.contains('readablehold') ||
        text.contains('hold') ||
        text.contains('pause') ||
        text.contains('settle') ||
        text.contains('read');
  }

  bool _isCompletionExemptComponent(ReFusionMotionDirectorComponent component) {
    final role = _normalizeToken('${component.role} ${component.label}');
    return role.contains('background') ||
        role.contains('canvas') ||
        role.contains('transition') ||
        role.contains('mask') ||
        role.contains('cover');
  }

  void _lintSceneProgramChannels({
    required List<ReFusionSceneProgramChannel> ownerChannels,
    required String ownerPath,
    required int ownerDurationMs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final seenTracks = <String, int>{};
    for (var channelIndex = 0;
        channelIndex < ownerChannels.length;
        channelIndex += 1) {
      final channel = ownerChannels[channelIndex];
      final trackKey =
          '${_normalizeToken(channel.target)}::${_normalizeToken(channel.property)}';
      final previousIndex = seenTracks[trackKey];
      if (previousIndex != null) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Duplicate Scene Program channel `${channel.property}` targets `${channel.target}`. Merge same-target/property motion into one ordered channel.',
            path: '$ownerPath[$channelIndex]',
          ),
        );
      } else {
        seenTracks[trackKey] = channelIndex;
      }
      if (channel.keyframes.isEmpty) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Channel `${channel.property}` must include keyframes.',
            path: '$ownerPath[$channelIndex].keyframes',
          ),
        );
      }
      var previousTimeMs = -1;
      for (var keyframeIndex = 0;
          keyframeIndex < channel.keyframes.length;
          keyframeIndex += 1) {
        final keyframe = channel.keyframes[keyframeIndex];
        if (keyframe.timeMs < 0 || keyframe.timeMs > ownerDurationMs) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message:
                  'Keyframe `timeMs` must be inside the owning layer duration.',
              path: '$ownerPath[$channelIndex].keyframes[$keyframeIndex]',
            ),
          );
        }
        if (keyframe.timeMs < previousTimeMs) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message: 'Keyframes must be sorted by ascending `timeMs`.',
              path: '$ownerPath[$channelIndex].keyframes[$keyframeIndex]',
            ),
          );
        }
        previousTimeMs = keyframe.timeMs;
      }
    }
  }

  String? _propertyGroupForPrimitive(
    ReFusionMotionDirectorPrimitive primitive,
  ) {
    final explicit = primitive.property?.trim();
    final property = explicit != null && explicit.isNotEmpty
        ? explicit
        : _propertyForPrimitiveKind(primitive.kind);
    if (property == null) {
      return null;
    }
    final normalized = _normalizeToken(property);
    if (normalized == 'positionx' ||
        normalized == 'positiony' ||
        normalized == 'x' ||
        normalized == 'y') {
      return 'position';
    }
    if (normalized == 'scalex' || normalized == 'scaley') {
      return 'scale';
    }
    if (normalized == 'typingprogress' ||
        normalized == 'letterrevealprogress' ||
        normalized == 'letterreveal' ||
        normalized == 'typewriter' ||
        normalized == 'typewriterprogress' ||
        normalized == 'texttypingprogress') {
      return 'typewriterprogress';
    }
    return normalized;
  }

  String? _propertyForPrimitiveKind(String kind) {
    final normalizedKind = _normalizeToken(kind);
    if (normalizedKind == 'typewriter' ||
        normalizedKind == 'typing' ||
        normalizedKind == 'letterreveal') {
      return 'typewriterProgress';
    }
    if (normalizedKind == 'enter' ||
        normalizedKind == 'fade' ||
        normalizedKind == 'opacity') {
      return 'opacity';
    }
    if (normalizedKind == 'move' || normalizedKind == 'slide') {
      return 'position';
    }
    if (normalizedKind == 'scale' ||
        normalizedKind == 'press' ||
        normalizedKind == 'cover') {
      return 'scale';
    }
    if (normalizedKind == 'widthgrow' || normalizedKind == 'linegrow') {
      return 'width';
    }
    if (normalizedKind == 'blur' || normalizedKind == 'deblur') {
      return 'blur';
    }
    if (normalizedKind == 'colorpulse' || normalizedKind == 'color') {
      return 'color';
    }
    return null;
  }

  String _normalizeToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
