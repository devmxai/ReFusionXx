import 'dart:collection';

class SemanticSceneBlueprint {
  SemanticSceneBlueprint({
    required this.schemaVersion,
    required this.name,
    required this.durationMs,
    required this.frameRate,
    List<SemanticSceneBlueprintComponent> components =
        const <SemanticSceneBlueprintComponent>[],
    List<SemanticSceneBlueprintBeat> beats =
        const <SemanticSceneBlueprintBeat>[],
    Map<String, Object?> metadata = const <String, Object?>{},
  })  : components = List.unmodifiable(components),
        beats = List.unmodifiable(beats),
        metadata = UnmodifiableMapView<String, Object?>(metadata);

  final String schemaVersion;
  final String name;
  final int durationMs;
  final double frameRate;
  final List<SemanticSceneBlueprintComponent> components;
  final List<SemanticSceneBlueprintBeat> beats;
  final Map<String, Object?> metadata;
}

class SemanticSceneBlueprintComponent {
  SemanticSceneBlueprintComponent({
    required this.id,
    required this.type,
    Map<String, Object?> properties = const <String, Object?>{},
    Map<String, Object?> slots = const <String, Object?>{},
    Map<String, Object?> motionIntents = const <String, Object?>{},
  })  : properties = UnmodifiableMapView<String, Object?>(properties),
        slots = UnmodifiableMapView<String, Object?>(slots),
        motionIntents = UnmodifiableMapView<String, Object?>(motionIntents);

  final String id;
  final String type;
  final Map<String, Object?> properties;
  final Map<String, Object?> slots;
  final Map<String, Object?> motionIntents;
}

class SemanticSceneBlueprintBeat {
  const SemanticSceneBlueprintBeat({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.intent,
  });

  final String id;
  final int startMs;
  final int endMs;
  final String intent;
}
