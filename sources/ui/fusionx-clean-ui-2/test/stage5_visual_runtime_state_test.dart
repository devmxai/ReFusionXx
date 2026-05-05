import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/core/engine/stage5_visual_runtime_state.dart';

void main() {
  test('serializes effect renderer bindings for native Stage5 runtime', () {
    const state = Stage5VisualRuntimeState(
      revision: 7,
      timelineTimeMs: 1200,
      mode: 'manualTransition',
      surfaces: <Stage5VisualRuntimeSurfaceState>[
        Stage5VisualRuntimeSurfaceState(
          targetClipId: 'clip-a',
          role: 'outgoing',
          transformMatrix3x3: <double>[
            1,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            1,
          ],
          opacity: 1,
          effectProgramIds: <String>['gaussianBlur'],
          effectBindings: <Stage5VisualRuntimeEffectBinding>[
            Stage5VisualRuntimeEffectBinding(
              id: 'gaussianBlur',
              rendererValue: 5.75,
              rendererUnit: 'shaderSigmaPx',
            ),
          ],
          motionBlurPolicy: Stage5VisualRuntimeMotionBlurPolicy(
            enabled: true,
            amount: 0.8,
            shutterAngleDegrees: 270,
            shutterPhaseDegrees: -135,
            samples: 12,
            adaptiveSampleLimit: 24,
            maxTrailPx: 360,
            affectPosition: true,
            affectScale: true,
            affectRotation: true,
          ),
          motionBlurSamples: <Stage5VisualRuntimeMotionBlurSample>[
            Stage5VisualRuntimeMotionBlurSample(
              timelineTimeMs: 1184,
              transformMatrix3x3: <double>[
                1,
                0,
                -18,
                0,
                1,
                0,
                0,
                0,
                1,
              ],
              opacity: 1,
            ),
            Stage5VisualRuntimeMotionBlurSample(
              timelineTimeMs: 1200,
              transformMatrix3x3: <double>[
                1,
                0,
                0,
                0,
                1,
                0,
                0,
                0,
                1,
              ],
              opacity: 1,
            ),
          ],
        ),
      ],
    );

    final map = state.toMap();
    final surfaces = map['surfaces'] as List<Object?>;
    final surface = surfaces.single as Map<String, Object?>;
    expect(surface['effectProgramIds'], <String>['gaussianBlur']);

    final bindings = surface['effectBindings'] as List<Object?>;
    final binding = bindings.single as Map<String, Object?>;
    expect(binding['id'], 'gaussianBlur');
    expect(binding['rendererValue'], 5.75);
    expect(binding['rendererUnit'], 'shaderSigmaPx');

    final motionBlurPolicy =
        surface['motionBlurPolicy'] as Map<String, Object?>;
    expect(motionBlurPolicy['enabled'], isTrue);
    expect(motionBlurPolicy['amount'], 0.8);
    expect(motionBlurPolicy['shutterAngleDegrees'], 270);
    expect(motionBlurPolicy['samples'], 12);
    expect(motionBlurPolicy['maxTrailPx'], 360);

    final motionBlurSamples = surface['motionBlurSamples'] as List<Object?>;
    expect(motionBlurSamples, hasLength(2));
    final firstSample = motionBlurSamples.first as Map<String, Object?>;
    expect(firstSample['timelineTimeMs'], 1184);
    expect(firstSample['opacity'], 1);
    expect(firstSample['transformMatrix3x3'], <double>[
      1,
      0,
      -18,
      0,
      1,
      0,
      0,
      0,
      1,
    ]);
  });
}
