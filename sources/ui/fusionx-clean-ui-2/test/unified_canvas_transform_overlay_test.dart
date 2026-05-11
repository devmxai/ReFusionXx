import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/widgets/unified_canvas_transform_overlay.dart';

void main() {
  const selectionBoxKey = ValueKey<String>(
    'unifiedCanvasTransformSelectionBox',
  );

  UnifiedCanvasTransformSnapshot snapshotWithNodes(
    List<UnifiedCanvasTransformNode> nodes,
  ) {
    return UnifiedCanvasTransformSnapshot(
      canvasSize: const MotionSize2D(width: 1080, height: 1920),
      nodes: nodes,
    );
  }

  UnifiedCanvasTransformNode videoNode({
    String id = 'video-clip',
    double x = 0,
    double y = 0,
  }) {
    return UnifiedCanvasTransformNode(
      id: id,
      layerId: id,
      kind: UnifiedCanvasTransformNodeKind.video,
      positionX: x,
      positionY: y,
      width: 1080,
      height: 1920,
      scaleX: 1,
      scaleY: 1,
      rotationDegrees: 0,
      opacity: 1,
      zIndex: 1,
    );
  }

  Widget host({
    required UnifiedCanvasTransformSnapshot snapshot,
    String? selectedElementId,
    ValueChanged<String>? onNodeSelected,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 540,
        height: 960,
        child: UnifiedCanvasTransformOverlay(
          snapshot: snapshot,
          selectedElementId: selectedElementId,
          isInteractive: true,
          onNodeSelected: onNodeSelected ?? (_) {},
          onNodeEditRequested: (_) {},
          onNodeMoved: (_, __) {},
          onNodeScaleChanged: (_, __, ___) {},
          onNodeRotationChanged: (_, __) {},
        ),
      ),
    );
  }

  testWidgets('auto-shows handles when a single transform node exists',
      (tester) async {
    await tester.pumpWidget(
      host(
        snapshot: snapshotWithNodes(<UnifiedCanvasTransformNode>[
          videoNode(),
        ]),
      ),
    );

    expect(find.byKey(selectionBoxKey), findsOneWidget);
  });

  testWidgets('does not auto-select when several transform nodes exist',
      (tester) async {
    await tester.pumpWidget(
      host(
        snapshot: snapshotWithNodes(<UnifiedCanvasTransformNode>[
          videoNode(id: 'first-video', x: -160),
          videoNode(id: 'second-video', x: 160),
        ]),
      ),
    );

    expect(find.byKey(selectionBoxKey), findsNothing);
  });

  testWidgets(
      'an existing selected node reveals handles without a drag gesture',
      (tester) async {
    await tester.pumpWidget(
      host(
        snapshot: snapshotWithNodes(<UnifiedCanvasTransformNode>[
          videoNode(id: 'first-video', x: -160),
          videoNode(id: 'second-video', x: 160),
        ]),
        selectedElementId: 'second-video',
      ),
    );

    expect(find.byKey(selectionBoxKey), findsOneWidget);
  });

  testWidgets('transform chrome does not consume empty canvas taps',
      (tester) async {
    var backgroundTapCount = 0;
    var selectedNodeCount = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => backgroundTapCount += 1,
          child: SizedBox(
            width: 540,
            height: 960,
            child: UnifiedCanvasTransformOverlay(
              snapshot: snapshotWithNodes(<UnifiedCanvasTransformNode>[
                videoNode(id: 'selected-video', x: 0, y: 0),
              ]),
              selectedElementId: 'selected-video',
              isInteractive: true,
              onNodeSelected: (_) => selectedNodeCount += 1,
              onNodeEditRequested: (_) {},
              onNodeMoved: (_, __) {},
              onNodeScaleChanged: (_, __, ___) {},
              onNodeRotationChanged: (_, __) {},
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(270, 480));

    expect(backgroundTapCount, 1);
    expect(selectedNodeCount, 0);
  });

  testWidgets('dragging selected node body moves the node', (tester) async {
    Offset? movedDelta;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 540,
          height: 960,
          child: UnifiedCanvasTransformOverlay(
            snapshot: snapshotWithNodes(<UnifiedCanvasTransformNode>[
              videoNode(id: 'selected-video', x: 0, y: 0),
            ]),
            selectedElementId: 'selected-video',
            isInteractive: true,
            onNodeSelected: (_) {},
            onNodeEditRequested: (_) {},
            onNodeMoved: (_, delta) => movedDelta = delta,
            onNodeScaleChanged: (_, __, ___) {},
            onNodeRotationChanged: (_, __) {},
          ),
        ),
      ),
    );

    await tester.dragFrom(const Offset(270, 480), const Offset(24, 18));

    expect(movedDelta, isNotNull);
    expect(movedDelta!.dx, greaterThan(0));
    expect(movedDelta!.dy, greaterThan(0));
  });
}
