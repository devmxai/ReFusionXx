enum ReFusionSceneProgramIssueSeverity {
  error,
  warning,
  info,
}

class ReFusionSceneProgramIssue {
  const ReFusionSceneProgramIssue({
    required this.severity,
    required this.message,
    this.path,
  });

  final ReFusionSceneProgramIssueSeverity severity;
  final String message;
  final String? path;
}

class ReFusionSceneProgram {
  ReFusionSceneProgram({
    required this.schemaVersion,
    required this.name,
    required this.durationMs,
    required this.frameRate,
    List<ReFusionSceneProgramLayer> layers =
        const <ReFusionSceneProgramLayer>[],
  }) : layers = List.unmodifiable(layers);

  final String schemaVersion;
  final String name;
  final int durationMs;
  final double frameRate;
  final List<ReFusionSceneProgramLayer> layers;
}

class ReFusionSceneProgramLayer {
  ReFusionSceneProgramLayer({
    required this.id,
    required this.kind,
    required this.startMs,
    required this.durationMs,
    this.name,
    List<ReFusionSceneProgramElement> elements =
        const <ReFusionSceneProgramElement>[],
    List<ReFusionSceneProgramChannel> channels =
        const <ReFusionSceneProgramChannel>[],
  })  : elements = List.unmodifiable(elements),
        channels = List.unmodifiable(channels);

  final String id;
  final String kind;
  final String? name;
  final int startMs;
  final int durationMs;
  final List<ReFusionSceneProgramElement> elements;
  final List<ReFusionSceneProgramChannel> channels;
}

class ReFusionSceneProgramElement {
  ReFusionSceneProgramElement({
    required this.id,
    required this.kind,
    this.name,
    this.text,
    Map<String, Object?> properties = const <String, Object?>{},
    List<ReFusionSceneProgramChannel> channels =
        const <ReFusionSceneProgramChannel>[],
  })  : properties = Map.unmodifiable(properties),
        channels = List.unmodifiable(channels);

  final String id;
  final String kind;
  final String? name;
  final String? text;
  final Map<String, Object?> properties;
  final List<ReFusionSceneProgramChannel> channels;
}

class ReFusionSceneProgramChannel {
  ReFusionSceneProgramChannel({
    required this.target,
    required this.property,
    List<ReFusionSceneProgramKeyframe> keyframes =
        const <ReFusionSceneProgramKeyframe>[],
  }) : keyframes = List.unmodifiable(keyframes);

  final String target;
  final String property;
  final List<ReFusionSceneProgramKeyframe> keyframes;
}

class ReFusionSceneProgramKeyframe {
  const ReFusionSceneProgramKeyframe({
    required this.timeMs,
    required this.value,
    this.easing = 'linear',
  });

  final int timeMs;
  final Object value;
  final String easing;
}
