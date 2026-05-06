import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/core/engine/stage5_visual_runtime_state.dart';

void main() {
  test('serializes Stage5 runtime effect bindings and motion blur directive',
      () {
    const state = Stage5VisualRuntimeState(
      revision: 7,
      timelineTimeMs: 1200,
      mode: 'manualTransition',
      framePacket: Stage5VisualFramePacket(
        timelineTimeMs: 1200,
        frameIndex: 36,
        mode: 'playback',
        revision: 7,
        targetClipId: 'clip-a',
        sourceId: 'clip-a',
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
        gaussianBlurSigmaPx: 5.75,
        effectValuesHash: 12345,
      ),
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
          motionBlurDirective: Stage5VisualRuntimeMotionBlurDirective(
            enabled: true,
            amount: 0.8,
            kernelLengthPx: 36,
            directionX: 1,
            directionY: 0,
            radialOmega: 0.12,
            scaleVelocityX: 0.04,
            scaleVelocityY: 0.03,
            anchorXNormalized: 0.5,
            anchorYNormalized: 0.5,
            shutterAngleDegrees: 270,
            shutterPhase: -0.5,
            sampleCount: 8,
            maxTrailPx: 360,
            mode: 'transformVelocity',
          ),
        ),
      ],
    );

    final map = state.toMap();
    final framePacket = map['framePacket'] as Map<String, Object?>;
    expect(framePacket['timelineTimeMs'], 1200);
    expect(framePacket['frameIndex'], 36);
    expect(framePacket['targetClipId'], 'clip-a');
    expect(framePacket['effectValuesHash'], 12345);
    final surfaces = map['surfaces'] as List<Object?>;
    final surface = surfaces.single as Map<String, Object?>;
    expect(surface['effectProgramIds'], <String>['gaussianBlur']);

    final bindings = surface['effectBindings'] as List<Object?>;
    final binding = bindings.single as Map<String, Object?>;
    expect(binding['id'], 'gaussianBlur');
    expect(binding['rendererValue'], 5.75);
    expect(binding['rendererUnit'], 'shaderSigmaPx');

    final motionBlurDirective =
        surface['motionBlurDirective'] as Map<String, Object?>;
    expect(motionBlurDirective['enabled'], isTrue);
    expect(motionBlurDirective['amount'], 0.8);
    expect(motionBlurDirective['kernelLengthPx'], 36.0);
    expect(motionBlurDirective['directionX'], 1.0);
    expect(motionBlurDirective['directionY'], 0.0);
    expect(motionBlurDirective['radialOmega'], 0.12);
    expect(motionBlurDirective['scaleVelocityX'], 0.04);
    expect(motionBlurDirective['scaleVelocityY'], 0.03);
    expect(motionBlurDirective['anchorXNormalized'], 0.5);
    expect(motionBlurDirective['anchorYNormalized'], 0.5);
    expect(motionBlurDirective['shutterAngleDegrees'], 270.0);
    expect(motionBlurDirective['shutterPhase'], -0.5);
    expect(motionBlurDirective['sampleCount'], 8);
    expect(motionBlurDirective['maxTrailPx'], 360.0);
    expect(motionBlurDirective['mode'], 'transformVelocity');
  });
}
