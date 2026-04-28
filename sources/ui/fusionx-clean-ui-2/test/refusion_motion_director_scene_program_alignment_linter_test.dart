import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_director_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_motion_director_scene_program_alignment_linter.dart';

void main() {
  const linter = ReFusionMotionDirectorSceneProgramAlignmentLinter();

  test('aligns background component to bg solid opacity channel', () {
    final result = linter.lint(
      plan: _backgroundPlan(),
      program: _programWithBgSolid(hasOpacityChannel: true),
    );

    expect(result.isValid, isTrue);
  });

  test('aligns background component through layer or element name aliases', () {
    final result = linter.lint(
      plan: _backgroundPlan(),
      program: ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'Named Background',
        durationMs: 1200,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'visual-fill-layer',
            kind: 'shape',
            name: 'Background',
            startMs: 0,
            durationMs: 1200,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'visual-fill',
                kind: 'shape',
                name: 'Canvas Fill',
                properties: const <String, Object?>{
                  'shapeKind': 'rectangle',
                  'width': 1080,
                  'height': 1920,
                },
                channels: <ReFusionSceneProgramChannel>[
                  ReFusionSceneProgramChannel(
                    target: 'visual-fill',
                    property: 'opacity',
                    keyframes: <ReFusionSceneProgramKeyframe>[
                      const ReFusionSceneProgramKeyframe(timeMs: 0, value: 0.0),
                      const ReFusionSceneProgramKeyframe(
                          timeMs: 500, value: 1.0),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    expect(result.isValid, isTrue);
  });

  test('aligns background component to full-canvas solid fill', () {
    final result = linter.lint(
      plan: _backgroundPlan(),
      program: ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'Canvas Fill',
        durationMs: 1200,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'fill-layer',
            kind: 'shape',
            startMs: 0,
            durationMs: 1200,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'fill-rect',
                kind: 'solid',
                properties: const <String, Object?>{
                  'width': 1080,
                  'height': 1920,
                  'color': '#090A0F',
                },
                channels: <ReFusionSceneProgramChannel>[
                  ReFusionSceneProgramChannel(
                    target: 'fill-rect',
                    property: 'opacity',
                    keyframes: <ReFusionSceneProgramKeyframe>[
                      const ReFusionSceneProgramKeyframe(timeMs: 0, value: 0.0),
                      const ReFusionSceneProgramKeyframe(
                          timeMs: 500, value: 1.0),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    expect(result.isValid, isTrue);
  });

  test('rejects static background opacity without matching animation channel',
      () {
    final result = linter.lint(
      plan: _backgroundPlan(),
      program: _programWithBgSolid(hasOpacityChannel: false),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((issue) => issue.message).join('\n'),
      contains('does not include that channel'),
    );
  });

  test('does not use background aliases for unrelated components', () {
    final result = linter.lint(
      plan: _titlePlan(),
      program: _programWithBgSolid(hasOpacityChannel: true),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((issue) => issue.message).join('\n'),
      contains('Director component `title` is not represented'),
    );
  });
}

ReFusionMotionDirectorPlan _backgroundPlan() {
  return ReFusionMotionDirectorPlan(
    schemaVersion: ReFusionMotionDirectorPlan.currentSchemaVersion,
    name: 'Background Plan',
    durationMs: 1200,
    frameRate: 30,
    canvasWidth: 1080,
    canvasHeight: 1920,
    beats: <ReFusionMotionDirectorBeat>[
      ReFusionMotionDirectorBeat(
        id: 'bg-enter',
        label: 'Background Enter',
        startMs: 0,
        endMs: 500,
        intent: 'Fade in background.',
        componentRefs: const <String>['background'],
      ),
    ],
    components: <ReFusionMotionDirectorComponent>[
      ReFusionMotionDirectorComponent(
        id: 'background',
        role: 'background.canvas',
        label: 'Background',
      ),
    ],
    primitives: const <ReFusionMotionDirectorPrimitive>[
      ReFusionMotionDirectorPrimitive(
        id: 'bg-fade',
        beatId: 'bg-enter',
        targetComponentId: 'background',
        kind: 'fade',
        property: 'opacity',
        startMs: 0,
        endMs: 500,
      ),
    ],
  );
}

ReFusionMotionDirectorPlan _titlePlan() {
  return ReFusionMotionDirectorPlan(
    schemaVersion: ReFusionMotionDirectorPlan.currentSchemaVersion,
    name: 'Title Plan',
    durationMs: 1200,
    frameRate: 30,
    beats: <ReFusionMotionDirectorBeat>[
      ReFusionMotionDirectorBeat(
        id: 'title-enter',
        label: 'Title Enter',
        startMs: 0,
        endMs: 500,
        intent: 'Fade in title.',
        componentRefs: const <String>['title'],
      ),
    ],
    components: <ReFusionMotionDirectorComponent>[
      ReFusionMotionDirectorComponent(
        id: 'title',
        role: 'text.title',
        label: 'Title',
      ),
    ],
    primitives: const <ReFusionMotionDirectorPrimitive>[
      ReFusionMotionDirectorPrimitive(
        id: 'title-fade',
        beatId: 'title-enter',
        targetComponentId: 'title',
        kind: 'fade',
        property: 'opacity',
        startMs: 0,
        endMs: 500,
      ),
    ],
  );
}

ReFusionSceneProgram _programWithBgSolid({required bool hasOpacityChannel}) {
  return ReFusionSceneProgram(
    schemaVersion: 'refusion.scene-program/v1',
    name: 'BG Scene',
    durationMs: 1200,
    frameRate: 30,
    layers: <ReFusionSceneProgramLayer>[
      ReFusionSceneProgramLayer(
        id: 'bg-layer',
        kind: 'shape',
        startMs: 0,
        durationMs: 1200,
        elements: <ReFusionSceneProgramElement>[
          ReFusionSceneProgramElement(
            id: 'bg-solid',
            kind: 'shape',
            properties: const <String, Object?>{
              'shapeKind': 'rectangle',
              'width': 1080,
              'height': 1920,
              'opacity': 1.0,
            },
            channels: hasOpacityChannel
                ? <ReFusionSceneProgramChannel>[
                    ReFusionSceneProgramChannel(
                      target: 'bg-solid',
                      property: 'opacity',
                      keyframes: <ReFusionSceneProgramKeyframe>[
                        const ReFusionSceneProgramKeyframe(
                            timeMs: 0, value: 0.0),
                        const ReFusionSceneProgramKeyframe(
                            timeMs: 500, value: 1.0),
                      ],
                    ),
                  ]
                : const <ReFusionSceneProgramChannel>[],
          ),
        ],
      ),
    ],
  );
}
