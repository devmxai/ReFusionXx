import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_evaluation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/widgets/motion_shape_preview_overlay.dart';
import 'package:refusion_app/features/editor/presentation/widgets/preview_stage.dart';

void main() {
  testWidgets('renders scene-program soft shadow properties on shapes',
      (tester) async {
    const target = MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: 'card',
      projectId: 'project',
      sceneId: 'scene',
      layerId: 'layer',
      elementId: 'card',
    );

    MotionEvaluatedPropertyValue property(
      MotionPropertyDefinition definition,
      MotionPropertyValue value,
    ) {
      return MotionEvaluatedPropertyValue(
        target: target,
        definition: definition,
        value: value,
        status: MotionEvaluationStatus.resolved,
      );
    }

    final snapshot = MotionEvaluationSnapshot(
      projectId: 'project',
      time: TimelineTime.zero,
      scenes: <MotionEvaluatedSceneState>[
        MotionEvaluatedSceneState(
          id: 'scene',
          sourceSceneId: 'scene',
          projectRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: TimelineTime.fromMilliseconds(1000),
          ),
          activationState: MotionActivationState.active,
          properties: const <MotionEvaluatedPropertyValue>[],
          layers: <MotionEvaluatedLayerState>[
            MotionEvaluatedLayerState(
              id: 'layer',
              sourceLayerId: 'layer',
              sceneId: 'scene',
              kind: MotionLayerKind.shape,
              projectRange: TimelineTimeRange(
                start: TimelineTime.zero,
                endExclusive: TimelineTime.fromMilliseconds(1000),
              ),
              activationState: MotionActivationState.active,
              properties: const <MotionEvaluatedPropertyValue>[],
              elements: <MotionEvaluatedElementState>[
                MotionEvaluatedElementState(
                  id: 'card',
                  sourceElementId: 'card',
                  sceneId: 'scene',
                  layerId: 'layer',
                  kind: MotionElementKind.shape,
                  shapeKind: MotionShapeKind.roundedRectangle,
                  projectRange: TimelineTimeRange(
                    start: TimelineTime.zero,
                    endExclusive: TimelineTime.fromMilliseconds(1000),
                  ),
                  activationState: MotionActivationState.active,
                  properties: <MotionEvaluatedPropertyValue>[
                    property(
                      MotionPropertyCatalog.width,
                      const MotionPropertyValue.scalar(120),
                    ),
                    property(
                      MotionPropertyCatalog.height,
                      const MotionPropertyValue.scalar(80),
                    ),
                    property(
                      MotionPropertyCatalog.cornerRadius,
                      const MotionPropertyValue.scalar(24),
                    ),
                    property(
                      MotionPropertyCatalog.opacity,
                      const MotionPropertyValue.scalar(1),
                    ),
                    property(
                      MotionPropertyCatalog.shadowOpacity,
                      const MotionPropertyValue.scalar(0.35),
                    ),
                    property(
                      MotionPropertyCatalog.shadowBlur,
                      const MotionPropertyValue.scalar(28),
                    ),
                    property(
                      MotionPropertyCatalog.shadowOffsetX,
                      const MotionPropertyValue.scalar(0),
                    ),
                    property(
                      MotionPropertyCatalog.shadowOffsetY,
                      const MotionPropertyValue.scalar(18),
                    ),
                    property(
                      MotionPropertyCatalog.shadowSpread,
                      const MotionPropertyValue.scalar(2),
                    ),
                    property(
                      MotionPropertyCatalog.shadowColor,
                      const MotionPropertyValue.colorArgb(0xFF111111),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 200,
          height: 200,
          child: MotionShapePreviewOverlay(
            snapshot: snapshot,
            canvasSize: const MotionSize2D(width: 800, height: 600),
          ),
        ),
      ),
    );

    final decoratedBox = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final decoration = decoratedBox.decoration as BoxDecoration;
    final shadow = decoration.boxShadow!.single;

    expect(shadow.blurRadius, closeTo(28, 0.001));
    expect(shadow.spreadRadius, closeTo(2, 0.001));
    expect(shadow.offset.dy, closeTo(18, 0.001));
    expect(shadow.color.alpha, closeTo((255 * 0.35).round(), 1));
  });

  testWidgets('renders trim path progress on line shapes', (tester) async {
    const target = MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: 'line',
      projectId: 'project',
      sceneId: 'scene',
      layerId: 'layer',
      elementId: 'line',
    );

    MotionEvaluatedPropertyValue property(
      MotionPropertyDefinition definition,
      MotionPropertyValue value,
    ) {
      return MotionEvaluatedPropertyValue(
        target: target,
        definition: definition,
        value: value,
        status: MotionEvaluationStatus.resolved,
      );
    }

    final snapshot = MotionEvaluationSnapshot(
      projectId: 'project',
      time: TimelineTime.zero,
      scenes: <MotionEvaluatedSceneState>[
        MotionEvaluatedSceneState(
          id: 'scene',
          sourceSceneId: 'scene',
          projectRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: TimelineTime.fromMilliseconds(1000),
          ),
          activationState: MotionActivationState.active,
          properties: const <MotionEvaluatedPropertyValue>[],
          layers: <MotionEvaluatedLayerState>[
            MotionEvaluatedLayerState(
              id: 'layer',
              sourceLayerId: 'layer',
              sceneId: 'scene',
              kind: MotionLayerKind.shape,
              projectRange: TimelineTimeRange(
                start: TimelineTime.zero,
                endExclusive: TimelineTime.fromMilliseconds(1000),
              ),
              activationState: MotionActivationState.active,
              properties: const <MotionEvaluatedPropertyValue>[],
              elements: <MotionEvaluatedElementState>[
                MotionEvaluatedElementState(
                  id: 'line',
                  sourceElementId: 'line',
                  sceneId: 'scene',
                  layerId: 'layer',
                  kind: MotionElementKind.shape,
                  shapeKind: MotionShapeKind.line,
                  projectRange: TimelineTimeRange(
                    start: TimelineTime.zero,
                    endExclusive: TimelineTime.fromMilliseconds(1000),
                  ),
                  activationState: MotionActivationState.active,
                  properties: <MotionEvaluatedPropertyValue>[
                    property(
                      MotionPropertyCatalog.width,
                      const MotionPropertyValue.scalar(200),
                    ),
                    property(
                      MotionPropertyCatalog.height,
                      const MotionPropertyValue.scalar(10),
                    ),
                    property(
                      MotionPropertyCatalog.opacity,
                      const MotionPropertyValue.scalar(1),
                    ),
                    property(
                      MotionPropertyCatalog.trimStart,
                      const MotionPropertyValue.scalar(0.25),
                    ),
                    property(
                      MotionPropertyCatalog.trimEnd,
                      const MotionPropertyValue.scalar(0.75),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 800,
          height: 600,
          child: MotionShapePreviewOverlay(
            snapshot: snapshot,
            canvasSize: const MotionSize2D(width: 800, height: 600),
          ),
        ),
      ),
    );

    final decoratedBoxFinder = find.byType(DecoratedBox);
    expect(decoratedBoxFinder, findsOneWidget);
    expect(tester.getSize(decoratedBoxFinder).width, closeTo(100, 0.001));
    expect(tester.getSize(decoratedBoxFinder).height, closeTo(10, 0.001));
  });

  testWidgets('clips shape overlays to the preview canvas rounded mask',
      (tester) async {
    const target = MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: 'background',
      projectId: 'project',
      sceneId: 'scene',
      layerId: 'layer',
      elementId: 'background',
    );

    MotionEvaluatedPropertyValue property(
      MotionPropertyDefinition definition,
      MotionPropertyValue value,
    ) {
      return MotionEvaluatedPropertyValue(
        target: target,
        definition: definition,
        value: value,
        status: MotionEvaluationStatus.resolved,
      );
    }

    final snapshot = MotionEvaluationSnapshot(
      projectId: 'project',
      time: TimelineTime.zero,
      scenes: <MotionEvaluatedSceneState>[
        MotionEvaluatedSceneState(
          id: 'scene',
          sourceSceneId: 'scene',
          projectRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: TimelineTime.fromMilliseconds(1000),
          ),
          activationState: MotionActivationState.active,
          properties: const <MotionEvaluatedPropertyValue>[],
          layers: <MotionEvaluatedLayerState>[
            MotionEvaluatedLayerState(
              id: 'layer',
              sourceLayerId: 'layer',
              sceneId: 'scene',
              kind: MotionLayerKind.shape,
              projectRange: TimelineTimeRange(
                start: TimelineTime.zero,
                endExclusive: TimelineTime.fromMilliseconds(1000),
              ),
              activationState: MotionActivationState.active,
              properties: const <MotionEvaluatedPropertyValue>[],
              elements: <MotionEvaluatedElementState>[
                MotionEvaluatedElementState(
                  id: 'background',
                  sourceElementId: 'background',
                  sceneId: 'scene',
                  layerId: 'layer',
                  kind: MotionElementKind.shape,
                  shapeKind: MotionShapeKind.rectangle,
                  projectRange: TimelineTimeRange(
                    start: TimelineTime.zero,
                    endExclusive: TimelineTime.fromMilliseconds(1000),
                  ),
                  activationState: MotionActivationState.active,
                  properties: <MotionEvaluatedPropertyValue>[
                    property(
                      MotionPropertyCatalog.width,
                      const MotionPropertyValue.scalar(800),
                    ),
                    property(
                      MotionPropertyCatalog.height,
                      const MotionPropertyValue.scalar(600),
                    ),
                    property(
                      MotionPropertyCatalog.opacity,
                      const MotionPropertyValue.scalar(1),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 320,
          child: PreviewStage(
            workspaceAspectRatio: 1,
            hasVisibleContent: true,
            overlay: MotionShapePreviewOverlay(
              snapshot: snapshot,
              canvasSize: const MotionSize2D(width: 800, height: 600),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    final overlayClip = find.descendant(
      of: find.byType(MotionShapePreviewOverlay),
      matching: find.byType(ClipRRect),
    );

    expect(overlayClip, findsOneWidget);
    expect(
      tester.widget<ClipRRect>(overlayClip).borderRadius,
      BorderRadius.circular(PreviewStage.canvasBorderRadius),
    );
  });
}
