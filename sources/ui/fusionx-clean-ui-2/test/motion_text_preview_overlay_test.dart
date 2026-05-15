import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_render_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/widgets/motion_text_preview_overlay.dart';
import 'package:refusion_app/features/editor/presentation/widgets/preview_stage.dart';

void main() {
  testWidgets('clips text overlays to the preview canvas rounded mask',
      (tester) async {
    final snapshot = MotionTextRenderSnapshot(
      projectId: 'project',
      time: TimelineTime.zero,
      canvasSize: const MotionSize2D(width: 1080, height: 1920),
      nodes: <MotionTextRenderNode>[
        MotionTextRenderNode(
          id: 'text-node',
          targetElementId: 'text-element',
          sceneId: 'scene',
          layerId: 'layer',
          projectRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: TimelineTime.fromMilliseconds(1000),
          ),
          isActive: true,
          text: 'TEXT MOTION TEST',
          fullText: 'TEXT MOTION TEST',
          revealUnit: MotionTextRevealUnit.wholeText,
          revealProgress: null,
          hasRevealAnimation: false,
          animationKinds: const <MotionTextAnimationKind>[],
          animationProgressByKind: const <MotionTextAnimationKind, double>{},
          canvasOffset: const MotionPoint2D(x: 0, y: 0),
          scaleX: 1,
          scaleY: 1,
          rotationDegrees: 0,
          opacity: 1,
          blurAmount: 0,
          fontSize: 72,
          letterSpacing: 0,
          colorArgb: 0xFF111111,
          fontFamily: null,
          fontWeight: 800,
          fontStyle: 'normal',
          lineHeight: 1,
          textAlignment: 'center',
          anchor: 'center',
          blendMode: MotionBlendMode.normal,
          zIndex: 10,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: 640,
          child: PreviewStage(
            workspaceAspectRatio: 9 / 16,
            hasVisibleContent: true,
            overlay: MotionTextPreviewOverlay(snapshot: snapshot),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    final overlayClip = find.descendant(
      of: find.byType(MotionTextPreviewOverlay),
      matching: find.byType(ClipRRect),
    );

    expect(overlayClip, findsOneWidget);
    expect(
      tester.widget<ClipRRect>(overlayClip).borderRadius,
      BorderRadius.circular(PreviewStage.canvasBorderRadius),
    );
  });
}
