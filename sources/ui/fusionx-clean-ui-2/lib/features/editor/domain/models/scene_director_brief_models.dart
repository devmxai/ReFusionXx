import 'dart:collection';

class SceneDirectorBrief {
  SceneDirectorBrief({
    required this.intent,
    required this.audience,
    required this.mood,
    required this.primaryFocus,
    required this.rhythm,
    required this.aspect,
    required this.durationIntent,
    this.brandContext,
    this.visualStyle,
    List<SceneDirectorBriefElement> elements =
        const <SceneDirectorBriefElement>[],
    Map<String, Object?> metadata = const <String, Object?>{},
  })  : elements = List.unmodifiable(elements),
        metadata = UnmodifiableMapView<String, Object?>(metadata);

  static const String currentSchemaVersion = 'refusion.scene-director-brief/v1';

  final String intent;
  final String audience;
  final String mood;
  final String primaryFocus;
  final String rhythm;
  final String aspect;
  final String durationIntent;
  final String? brandContext;
  final String? visualStyle;
  final List<SceneDirectorBriefElement> elements;
  final Map<String, Object?> metadata;
}

class SceneDirectorBriefElement {
  SceneDirectorBriefElement({
    required this.kind,
    required this.importance,
    this.id,
    this.text,
    this.motionHint,
    this.iconToken,
    this.brandToken,
    List<SceneDirectorBriefCard> cards = const <SceneDirectorBriefCard>[],
    Map<String, Object?> properties = const <String, Object?>{},
  })  : cards = List.unmodifiable(cards),
        properties = UnmodifiableMapView<String, Object?>(properties);

  final String? id;
  final String kind;
  final String importance;
  final String? text;
  final String? motionHint;
  final String? iconToken;
  final String? brandToken;
  final List<SceneDirectorBriefCard> cards;
  final Map<String, Object?> properties;
}

class SceneDirectorBriefCard {
  const SceneDirectorBriefCard({
    required this.label,
    required this.body,
    this.iconToken,
    this.brandToken,
  });

  final String label;
  final String body;
  final String? iconToken;
  final String? brandToken;
}
