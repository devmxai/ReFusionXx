import 'package:flutter/foundation.dart';

@immutable
class SceneEvaluationDiagnosticEvent {
  const SceneEvaluationDiagnosticEvent({
    required this.tag,
    required this.fields,
  });

  final String tag;
  final Map<String, Object?> fields;

  Map<String, Object?> toDiagnosticMap() {
    return <String, Object?>{
      'tag': tag,
      'fields': fields,
    };
  }
}

@immutable
class SceneEvaluationDiagnostics {
  SceneEvaluationDiagnostics({
    required List<SceneEvaluationDiagnosticEvent> events,
  }) : events = List.unmodifiable(events);

  static const String frameTruthProofTag =
      'TF_SCENE_EVALUATED_FRAME_TRUTH_PROOF';

  final List<SceneEvaluationDiagnosticEvent> events;

  SceneEvaluationDiagnostics append({
    required String tag,
    required Map<String, Object?> fields,
  }) {
    return SceneEvaluationDiagnostics(
      events: <SceneEvaluationDiagnosticEvent>[
        ...events,
        SceneEvaluationDiagnosticEvent(tag: tag, fields: fields),
      ],
    );
  }

  Map<String, Object?> toDiagnosticMap() {
    return <String, Object?>{
      'count': events.length,
      'events': events.map((event) => event.toDiagnosticMap()).toList(),
    };
  }
}
