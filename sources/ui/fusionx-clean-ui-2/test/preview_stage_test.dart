import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/widgets/preview_stage.dart';

void main() {
  testWidgets('overlay can receive hits outside the centered canvas',
      (tester) async {
    var outsideCanvasTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 600,
          height: 400,
          child: PreviewStage(
            workspaceAspectRatio: 1,
            hasVisibleContent: true,
            child: const SizedBox.expand(),
            overlay: Builder(
              builder: (context) {
                final canvasRect =
                    PreviewStageCanvasViewport.maybeOf(context)!.canvasRect;
                return Stack(
                  children: [
                    Positioned(
                      left: canvasRect.right + 12,
                      top: canvasRect.center.dy - 12,
                      child: GestureDetector(
                        key: const ValueKey<String>(
                          'outsideCanvasOverlayHandle',
                        ),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => outsideCanvasTapCount += 1,
                        child: const SizedBox(width: 24, height: 24),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('outsideCanvasOverlayHandle')),
    );

    expect(outsideCanvasTapCount, 1);
  });
}
