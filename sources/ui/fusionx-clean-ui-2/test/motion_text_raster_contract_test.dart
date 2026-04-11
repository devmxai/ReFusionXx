import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_raster_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_render_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  MotionTextRenderNode buildRenderNode({
    double opacity = 0.9,
    double blurAmount = 10,
    double fontSize = 20,
    double letterSpacing = 4,
  }) {
    return MotionTextRenderNode(
      id: 'node-1',
      targetElementId: 'element-1',
      sceneId: 'scene-1',
      layerId: 'layer-1',
      projectRange: TimelineTimeRange(
        start: TimelineTime.zero,
        endExclusive: TimelineTime.fromMilliseconds(1200),
      ),
      isActive: true,
      text: 'professional',
      fullText: 'professional',
      revealUnit: MotionTextRevealUnit.wholeText,
      revealProgress: null,
      hasRevealAnimation: false,
      animationKinds: const <MotionTextAnimationKind>[],
      animationProgressByKind: const <MotionTextAnimationKind, double>{},
      canvasOffset: const MotionPoint2D(x: 24, y: -12),
      scaleX: 1.0,
      scaleY: 1.0,
      rotationDegrees: 12,
      opacity: opacity,
      blurAmount: blurAmount,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      colorArgb: 0xFFF3F3F3,
      fontFamily: null,
      fontWeight: 700,
      fontStyle: 'normal',
      lineHeight: 1.0,
      textAlignment: 'center',
      anchor: 'center',
      blendMode: MotionBlendMode.normal,
      zIndex: 10,
      name: 'Professional',
      presetId: 'text.professional',
    );
  }

  test('adapts render snapshot into a shared raster contract', () {
    final snapshot = MotionTextRenderSnapshot(
      projectId: 'project-1',
      time: TimelineTime.fromMilliseconds(400),
      canvasSize: const MotionSize2D(width: 1080, height: 1920),
      nodes: <MotionTextRenderNode>[
        buildRenderNode(),
      ],
    );

    final rasterSnapshot =
        const BasicMotionTextRasterContractAdapter().adapt(snapshot: snapshot);

    expect(rasterSnapshot.projectId, 'project-1');
    expect(
      rasterSnapshot.contract.contractVersion,
      kMotionTextRasterContractVersion,
    );
    expect(rasterSnapshot.contract.blurEngineId, 'gaussian_layer_blur');
    expect(
      rasterSnapshot.contract.blurColorResolutionMode,
      'alpha_mask_colorized',
    );
    expect(rasterSnapshot.nodes, hasLength(1));
    expect(rasterSnapshot.nodes.single.typography.fontSize, 20);
    expect(rasterSnapshot.nodes.single.effects.blurAmount, 10);
    expect(rasterSnapshot.nodes.single.layout.anchor, 'center');
  });

  test('resolves deterministic raster metrics from the shared contract', () {
    final rasterNode = const BasicMotionTextRasterContractAdapter()
        .adapt(
          snapshot: MotionTextRenderSnapshot(
            projectId: 'project-1',
            time: TimelineTime.fromMilliseconds(400),
            canvasSize: const MotionSize2D(width: 1080, height: 1920),
            nodes: <MotionTextRenderNode>[
              buildRenderNode(),
            ],
          ),
        )
        .nodes
        .single;

    final metrics = rasterNode.resolveMetrics(
      scaleX: 2.0,
      scaleY: 1.5,
    );

    expect(metrics.effectiveScale, closeTo(1.5, 0.0001));
    expect(metrics.translatedX, closeTo(48.0, 0.0001));
    expect(metrics.translatedY, closeTo(-18.0, 0.0001));
    expect(metrics.fontSizePx, closeTo(30.0, 0.0001));
    expect(metrics.letterSpacingPx, closeTo(6.0, 0.0001));
    expect(metrics.blurSigma, closeTo(2.7, 0.0001));
    expect(metrics.blurKernelSpreadPx, closeTo(8.1, 0.0001));
    expect(metrics.layoutPaddingPx, 9.0);
  });
}
