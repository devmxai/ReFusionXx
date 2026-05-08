import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_professional_taste_grammar.dart';

void main() {
  const grammar = SceneProfessionalTasteGrammar();

  test('emits taste grammar proof diagnostics', () {
    final report = grammar.evaluate(
      _buildProgram(
        name: 'Taste proof',
        textFont: 28,
        addDenseElements: false,
      ),
      profile: 'story_9_16',
    );

    expect(
      report.issues.any(
        (issue) =>
            issue.message.contains(kSceneTasteGrammarProofTag) &&
            issue.message.contains('profile=story_9_16') &&
            issue.message.contains('focalScore=') &&
            issue.message.contains('densityScore=') &&
            issue.message.contains('typeScaleScore=') &&
            issue.message.contains('motionPacingScore='),
      ),
      isTrue,
    );
  });

  test('valid but weak scene receives actionable taste suggestions', () {
    final report = grammar.evaluate(
      _buildProgram(
        name: 'Weak scene',
        textFont: 96,
        addDenseElements: true,
      ),
    );

    final suggestionCodes =
        report.suggestions.map((suggestion) => suggestion.code).toSet();
    expect(suggestionCodes.contains('TYPE_SCALE_IMBALANCED'), isTrue);
    expect(suggestionCodes.contains('CARD_DENSITY_IMBALANCED'), isTrue);
    expect(suggestionCodes.contains('FOCAL_HIERARCHY_WEAK'), isTrue);
    expect(
      report.issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.warning,
      ),
      isTrue,
    );
  });

  test('text fit risk is reported when bounded text policy is unsafe', () {
    final report = grammar.evaluate(
      _buildProgram(
        name: 'Text fit risk',
        textFont: 36,
        addDenseElements: false,
        forceUnsafeTextFit: true,
      ),
    );

    expect(
      report.suggestions
          .any((suggestion) => suggestion.code == 'TEXT_FIT_RISK'),
      isTrue,
    );
  });
}

ReFusionSceneProgram _buildProgram({
  required String name,
  required double textFont,
  required bool addDenseElements,
  bool forceUnsafeTextFit = false,
}) {
  final elements = <ReFusionSceneProgramElement>[
    ReFusionSceneProgramElement(
      id: 'headline',
      kind: 'text',
      text: 'Generate premium offer for business growth today',
      properties: <String, Object?>{
        'fontSize': textFont,
        'textFrame': <String, Object?>{
          'width': 360,
          'height': 64,
          'maxLines': 1,
          'overflow': forceUnsafeTextFit ? 'clip' : 'ellipsis',
          'fitPolicy': forceUnsafeTextFit ? 'none' : 'shrinkToFit',
        },
      },
    ),
    ReFusionSceneProgramElement(
      id: 'body',
      kind: 'text',
      text: 'One place for projects, feedback, files, and communication.',
      properties: const <String, Object?>{
        'fontSize': 20,
        'textFrame': <String, Object?>{
          'width': 620,
          'height': 96,
          'maxLines': 2,
          'overflow': 'ellipsis',
          'fitPolicy': 'shrinkToFit',
        },
      },
    ),
  ];

  if (addDenseElements) {
    for (var index = 0; index < 14; index += 1) {
      elements.add(
        ReFusionSceneProgramElement(
          id: 'shape-$index',
          kind: 'shape',
          properties: <String, Object?>{
            'width': 180,
            'height': 80,
          },
        ),
      );
    }
  }

  return ReFusionSceneProgram(
    schemaVersion: 'refusion.scene-program/v1',
    name: name,
    durationMs: 2800,
    frameRate: 30,
    layers: <ReFusionSceneProgramLayer>[
      ReFusionSceneProgramLayer(
        id: 'layer-main',
        kind: 'shape',
        startMs: 0,
        durationMs: 2800,
        elements: elements,
        channels: <ReFusionSceneProgramChannel>[
          ReFusionSceneProgramChannel(
            target: 'headline',
            property: 'opacity',
            keyframes: <ReFusionSceneProgramKeyframe>[
              const ReFusionSceneProgramKeyframe(timeMs: 0, value: 0.0),
              const ReFusionSceneProgramKeyframe(timeMs: 220, value: 1.0),
              const ReFusionSceneProgramKeyframe(timeMs: 1200, value: 1.0),
            ],
          ),
        ],
      ),
    ],
  );
}
