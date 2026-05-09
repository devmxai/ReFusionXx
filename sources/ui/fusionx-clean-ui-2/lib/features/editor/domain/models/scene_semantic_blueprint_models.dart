import 'dart:collection';

class SemanticSceneBlueprint {
  SemanticSceneBlueprint({
    required this.schemaVersion,
    required this.name,
    required this.durationMs,
    required this.frameRate,
    this.compositionIntent,
    this.tasteProfile,
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
  final String? compositionIntent;
  final String? tasteProfile;
  final List<SemanticSceneBlueprintComponent> components;
  final List<SemanticSceneBlueprintBeat> beats;
  final Map<String, Object?> metadata;
}

class SemanticSceneBlueprintComponent {
  SemanticSceneBlueprintComponent({
    required this.id,
    required this.type,
    this.variant,
    this.iconToken,
    this.brandToken,
    this.motionRecipe,
    this.fitPolicy,
    this.compositionIntent,
    this.microScene,
    this.tasteProfile,
    Map<String, Object?> properties = const <String, Object?>{},
    Map<String, Object?> slots = const <String, Object?>{},
    Map<String, Object?> motionIntents = const <String, Object?>{},
    Map<String, Object?> componentChoreography = const <String, Object?>{},
  })  : properties = UnmodifiableMapView<String, Object?>(properties),
        slots = UnmodifiableMapView<String, Object?>(slots),
        motionIntents = UnmodifiableMapView<String, Object?>(motionIntents),
        componentChoreography =
            UnmodifiableMapView<String, Object?>(componentChoreography);

  final String id;
  final String type;
  final String? variant;
  final String? iconToken;
  final String? brandToken;
  final String? motionRecipe;
  final String? fitPolicy;
  final String? compositionIntent;
  final String? microScene;
  final String? tasteProfile;
  final Map<String, Object?> properties;
  final Map<String, Object?> slots;
  final Map<String, Object?> motionIntents;
  final Map<String, Object?> componentChoreography;
}

class SemanticSceneBlueprintBeat {
  SemanticSceneBlueprintBeat({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.intent,
    List<String> componentRefs = const <String>[],
    this.overlapPolicy,
  }) : componentRefs = List.unmodifiable(componentRefs);

  final String id;
  final int startMs;
  final int endMs;
  final String intent;
  final List<String> componentRefs;
  final String? overlapPolicy;
}
