import '../models/master_render_graph_models.dart';
import '../models/master_visual_program_models.dart';

class MasterRenderGraphAdapter {
  const MasterRenderGraphAdapter();

  MasterRenderGraph build({
    required MasterVisualProgram program,
    int outputWidth = 1080,
    int outputHeight = 1920,
    String colorProfile = 'srgb',
  }) {
    final nodes = <MasterRenderGraphNode>[];
    final diagnostics = <String>[...program.diagnostics];
    final blockers = <String>[...program.blockers];
    final bindings = <MasterRenderSurfaceBinding>[];
    final orderedSurfaces = [...program.surfaces]..sort((left, right) {
        final orderCompare = left.drawOrder.compareTo(right.drawOrder);
        if (orderCompare != 0) {
          return orderCompare;
        }
        return left.targetId.compareTo(right.targetId);
      });

    for (final surface in orderedSurfaces) {
      final surfaceBlockers = <String>[...surface.blockers];
      final surfaceDiagnostics = <String>[];
      String? sourceNodeId;
      String? cropNodeId;
      String? maskNodeId;
      String? styleNodeId;
      String? motionBlurNodeId;
      String previousNodeId;

      final source = surface.source;
      if (source == null || source.sourceUri.trim().isEmpty) {
        surfaceBlockers.add('missing_source_binding:${surface.targetId}');
        previousNodeId = 'source:missing:${surface.targetId}';
      } else {
        sourceNodeId = 'source:${surface.targetId}';
        nodes.add(
          MasterRenderGraphNode(
            id: sourceNodeId,
            family: MasterRenderGraphNodeFamily.sourceSample,
            targetId: surface.targetId,
            cacheKey: _cacheKey(
              'source',
              surface.targetId,
              source.sourceUri,
              source.scrubStoreKey,
            ),
            attributes: <String, Object?>{
              'sourceUri': source.sourceUri,
              'sourceKind': source.kind.name,
              'scrubStoreKey': source.scrubStoreKey,
              'sourceWidth': source.sourceWidth,
              'sourceHeight': source.sourceHeight,
            },
            blockers: surfaceBlockers,
            diagnostics: surfaceDiagnostics,
          ),
        );
        previousNodeId = sourceNodeId;
      }

      final transformNodeId = 'transform:${surface.targetId}';
      nodes.add(
        MasterRenderGraphNode(
          id: transformNodeId,
          family: MasterRenderGraphNodeFamily.layerTransform,
          targetId: surface.targetId,
          inputNodeIds:
              sourceNodeId == null ? const <String>[] : <String>[sourceNodeId],
          cacheKey: _cacheKey(
            'transform',
            surface.targetId,
            surface.transform.positionX,
            surface.transform.positionY,
            surface.transform.scaleX,
            surface.transform.scaleY,
            surface.transform.rotationRadians,
            surface.opacity,
          ),
          attributes: <String, Object?>{
            'positionX': surface.transform.positionX,
            'positionY': surface.transform.positionY,
            'scaleX': surface.transform.scaleX,
            'scaleY': surface.transform.scaleY,
            'rotationRadians': surface.transform.rotationRadians,
            'opacity': surface.opacity,
          },
          blockers: surfaceBlockers,
          diagnostics: surfaceDiagnostics,
        ),
      );
      previousNodeId = transformNodeId;

      if (surface.crop.hasCrop) {
        cropNodeId = 'crop:${surface.targetId}';
        final rect = surface.crop.rect!;
        nodes.add(
          MasterRenderGraphNode(
            id: cropNodeId,
            family: MasterRenderGraphNodeFamily.crop,
            targetId: surface.targetId,
            inputNodeIds: <String>[previousNodeId],
            cacheKey: _cacheKey(
              'crop',
              surface.targetId,
              rect.left,
              rect.top,
              rect.width,
              rect.height,
            ),
            attributes: <String, Object?>{
              'left': rect.left,
              'top': rect.top,
              'width': rect.width,
              'height': rect.height,
            },
            blockers: surfaceBlockers,
            diagnostics: surfaceDiagnostics,
          ),
        );
        previousNodeId = cropNodeId;
      }

      if (surface.mask.hasMask) {
        maskNodeId = 'mask:${surface.targetId}';
        nodes.add(
          MasterRenderGraphNode(
            id: maskNodeId,
            family: MasterRenderGraphNodeFamily.mask,
            targetId: surface.targetId,
            inputNodeIds: <String>[previousNodeId],
            cacheKey: _cacheKey(
              'mask',
              surface.targetId,
              surface.mask.revealProgress,
            ),
            attributes: <String, Object?>{
              'revealProgress': surface.mask.revealProgress,
            },
            blockers: surfaceBlockers,
            diagnostics: surfaceDiagnostics,
          ),
        );
        previousNodeId = maskNodeId;
      }

      if (surface.textStyle.hasTextStyle ||
          surface.shapeStyle.hasShapeStyle ||
          surface.colors.hasColorStyle) {
        styleNodeId = 'style:${surface.targetId}';
        nodes.add(
          MasterRenderGraphNode(
            id: styleNodeId,
            family: MasterRenderGraphNodeFamily.style,
            targetId: surface.targetId,
            inputNodeIds: <String>[previousNodeId],
            cacheKey: _cacheKey(
              'style',
              surface.targetId,
              Object.hashAll(<Object?>[
                surface.textStyle.fontSize,
                surface.textStyle.fontWeight,
                surface.textStyle.fontFamily,
                surface.textStyle.fontStyle,
                surface.textStyle.lineHeight,
                surface.textStyle.alignment,
                surface.textStyle.letterSpacing,
                surface.textStyle.revealProgress,
                surface.shapeStyle.width,
                surface.shapeStyle.height,
                surface.shapeStyle.cornerRadius,
                surface.shapeStyle.trimStart,
                surface.shapeStyle.trimEnd,
                surface.shapeStyle.trimOffset,
                surface.colors.visualColorArgb,
                surface.colors.shadowColorArgb,
              ]),
            ),
            attributes: <String, Object?>{
              'text.fontSize': surface.textStyle.fontSize,
              'text.fontWeight': surface.textStyle.fontWeight,
              'text.fontFamily': surface.textStyle.fontFamily,
              'text.fontStyle': surface.textStyle.fontStyle,
              'text.lineHeight': surface.textStyle.lineHeight,
              'text.alignment': surface.textStyle.alignment,
              'text.letterSpacing': surface.textStyle.letterSpacing,
              'text.revealProgress': surface.textStyle.revealProgress,
              'shape.width': surface.shapeStyle.width,
              'shape.height': surface.shapeStyle.height,
              'shape.cornerRadius': surface.shapeStyle.cornerRadius,
              'shape.trimStart': surface.shapeStyle.trimStart,
              'shape.trimEnd': surface.shapeStyle.trimEnd,
              'shape.trimOffset': surface.shapeStyle.trimOffset,
              'visual.color': surface.colors.visualColorArgb,
              'effect.shadow.color': surface.colors.shadowColorArgb,
            },
            blockers: surfaceBlockers,
            diagnostics: surfaceDiagnostics,
          ),
        );
        previousNodeId = styleNodeId;
      }

      final effectNodeIds = <String>[];
      final sortedEffects = [...surface.effects]
        ..sort((left, right) => left.id.compareTo(right.id));
      for (final effect in sortedEffects) {
        final effectNodeId = 'effect:${surface.targetId}:${effect.id}';
        nodes.add(
          MasterRenderGraphNode(
            id: effectNodeId,
            family: MasterRenderGraphNodeFamily.effect,
            targetId: surface.targetId,
            inputNodeIds: <String>[previousNodeId],
            cacheKey: _cacheKey(
              'effect',
              surface.targetId,
              effect.id,
              effect.rendererValue,
              effect.rendererUnit.name,
            ),
            attributes: <String, Object?>{
              'effectId': effect.id,
              'rendererValue': effect.rendererValue,
              'rendererUnit': effect.rendererUnit.name,
            },
            blockers: surfaceBlockers,
            diagnostics: surfaceDiagnostics,
          ),
        );
        effectNodeIds.add(effectNodeId);
        previousNodeId = effectNodeId;
      }

      if (surface.motionBlur.isEnabled) {
        motionBlurNodeId = 'motionBlur:${surface.targetId}';
        final sampleOffsetsMs = _motionBlurSampleOffsetsMs(
          policy: surface.motionBlur,
          frameRate: program.time.frameRate,
        );
        nodes.add(
          MasterRenderGraphNode(
            id: motionBlurNodeId,
            family: MasterRenderGraphNodeFamily.temporalMotionBlur,
            targetId: surface.targetId,
            inputNodeIds: <String>[previousNodeId],
            cacheKey: _cacheKey(
              'motionBlur',
              surface.targetId,
              surface.motionBlur.amount,
              surface.motionBlur.shutterAngleDegrees,
              surface.motionBlur.shutterPhaseDegrees,
              surface.motionBlur.samples,
              Object.hashAll(sampleOffsetsMs),
            ),
            attributes: <String, Object?>{
              'effectId': 'temporalMotionBlur',
              'enabled': surface.motionBlur.enabled,
              'amount': surface.motionBlur.amount,
              'shutterAngleDegrees': surface.motionBlur.shutterAngleDegrees,
              'shutterPhaseDegrees': surface.motionBlur.shutterPhaseDegrees,
              'samples': surface.motionBlur.samples,
              'adaptiveSampleLimit': surface.motionBlur.adaptiveSampleLimit,
              'maxTrailPx': surface.motionBlur.maxTrailPx,
              'affectPosition': surface.motionBlur.affectPosition,
              'affectScale': surface.motionBlur.affectScale,
              'affectRotation': surface.motionBlur.affectRotation,
              'frameRate': program.time.frameRate,
              'sampleOffsetsMs': sampleOffsetsMs,
              'requiresTemporalSampling': true,
              'fallbackAllowed': false,
              'isSyntheticBlur': false,
            },
            blockers: surfaceBlockers,
            diagnostics: surfaceDiagnostics,
          ),
        );
        previousNodeId = motionBlurNodeId;
      }

      String? transitionNodeId;
      if (surface.transitionRole != MasterVisualTransitionRole.none) {
        transitionNodeId =
            'transition:${surface.targetId}:${surface.transitionRole.name}';
        nodes.add(
          MasterRenderGraphNode(
            id: transitionNodeId,
            family: MasterRenderGraphNodeFamily.transition,
            targetId: surface.targetId,
            inputNodeIds: <String>[previousNodeId],
            cacheKey: _cacheKey(
              'transition',
              surface.targetId,
              surface.transitionRole.name,
              program.transitionState.activeTransitionIds.join(','),
            ),
            attributes: <String, Object?>{
              'role': surface.transitionRole.name,
              'activeTransitionIds':
                  program.transitionState.activeTransitionIds,
              'hasRenderableTransitionPixels':
                  program.transitionState.hasRenderableTransitionPixels,
              'transitionReason': program.transitionState.reason,
            },
            blockers: surfaceBlockers,
            diagnostics: surfaceDiagnostics,
          ),
        );
        previousNodeId = transitionNodeId;
      }

      final compositeNodeId = 'composite:${surface.targetId}';
      nodes.add(
        MasterRenderGraphNode(
          id: compositeNodeId,
          family: MasterRenderGraphNodeFamily.composite,
          targetId: surface.targetId,
          inputNodeIds: <String>[previousNodeId],
          cacheKey: _cacheKey('composite', surface.targetId, previousNodeId),
          attributes: <String, Object?>{
            'drawOrder': surface.drawOrder,
            'transitionRole': surface.transitionRole.name,
            'sourceKind': surface.sourceKind.name,
            'hasCrop': surface.crop.hasCrop,
            'hasMask': surface.mask.hasMask,
            'hasTextStyle': surface.textStyle.hasTextStyle,
            'hasShapeStyle': surface.shapeStyle.hasShapeStyle,
            'hasColorStyle': surface.colors.hasColorStyle,
          },
          blockers: surfaceBlockers,
          diagnostics: surfaceDiagnostics,
        ),
      );

      blockers.addAll(surfaceBlockers);
      diagnostics.addAll(surfaceDiagnostics);
      bindings.add(
        MasterRenderSurfaceBinding(
          targetId: surface.targetId,
          sourceNodeId: sourceNodeId,
          transformNodeId: transformNodeId,
          cropNodeId: cropNodeId,
          maskNodeId: maskNodeId,
          styleNodeId: styleNodeId,
          effectNodeIds: effectNodeIds,
          motionBlurNodeId: motionBlurNodeId,
          transitionNodeId: transitionNodeId,
          compositeNodeId: compositeNodeId,
          drawOrder: surface.drawOrder,
          transitionRole: surface.transitionRole,
          blockers: surfaceBlockers,
        ),
      );
    }

    final outputNodeId = 'output:${program.time.renderMode.name}';
    final orderedComposites = [...bindings]..sort((left, right) {
        final orderCompare = left.drawOrder.compareTo(right.drawOrder);
        if (orderCompare != 0) {
          return orderCompare;
        }
        return left.targetId.compareTo(right.targetId);
      });
    nodes.add(
      MasterRenderGraphNode(
        id: outputNodeId,
        family: MasterRenderGraphNodeFamily.outputSurface,
        targetId: outputNodeId,
        inputNodeIds: orderedComposites
            .map((entry) => entry.compositeNodeId)
            .toList(growable: false),
        cacheKey: _cacheKey(
          'output',
          program.time.renderMode.name,
          outputWidth,
          outputHeight,
          colorProfile,
        ),
        attributes: <String, Object?>{
          'outputWidth': outputWidth,
          'outputHeight': outputHeight,
          'colorProfile': colorProfile,
        },
        blockers: blockers,
        diagnostics: diagnostics,
      ),
    );

    final revision = _buildRevision(
      program: program,
      nodes: nodes,
      blockers: blockers,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
      colorProfile: colorProfile,
    );
    diagnostics.add('master_render_graph_nodes:${nodes.length}');

    return MasterRenderGraph(
      revision: revision,
      rootTimeMs: program.time.rootTime.inMilliseconds,
      frameIndex: program.time.frameIndex,
      renderMode: program.time.renderMode,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
      colorProfile: colorProfile,
      nodes: nodes,
      surfaceBindings: bindings,
      outputNodeId: outputNodeId,
      blockers: blockers,
      diagnostics: diagnostics,
    );
  }

  String _buildRevision({
    required MasterVisualProgram program,
    required List<MasterRenderGraphNode> nodes,
    required List<String> blockers,
    required int outputWidth,
    required int outputHeight,
    required String colorProfile,
  }) {
    final signature = <Object?>[
      program.time.commitFrameNumber,
      program.time.frameIndex,
      program.time.rootTime.inProjectTicks,
      program.time.renderMode.name,
      outputWidth,
      outputHeight,
      colorProfile,
      for (final node in nodes) ...<Object?>[
        node.id,
        node.family.name,
        node.cacheKey,
        ...node.inputNodeIds,
      ],
      ...blockers,
    ];
    final hash = Object.hashAll(signature).toUnsigned(32).toRadixString(16);
    return 'mrg:${program.time.commitFrameNumber}:${program.time.frameIndex}:$hash';
  }

  String _cacheKey(
    String family,
    String targetId, [
    Object? valueA,
    Object? valueB,
    Object? valueC,
    Object? valueD,
    Object? valueE,
    Object? valueF,
  ]) {
    final hash = Object.hashAll(<Object?>[
      family,
      targetId,
      valueA,
      valueB,
      valueC,
      valueD,
      valueE,
      valueF,
    ]).toUnsigned(32).toRadixString(16);
    return '$family:$targetId:$hash';
  }

  List<double> _motionBlurSampleOffsetsMs({
    required MasterMotionBlurPolicy policy,
    required double frameRate,
  }) {
    final safeFrameRate =
        (frameRate.isFinite && frameRate > 0 ? frameRate : 30.0).toDouble();
    final frameDurationMs = 1000.0 / safeFrameRate;
    final exposureMs = frameDurationMs *
        (policy.shutterAngleDegrees.clamp(0.0, 1440.0).toDouble() / 360.0) *
        policy.amount.clamp(0.0, 1.0).toDouble();
    final phaseStartMs = frameDurationMs *
        (policy.shutterPhaseDegrees.clamp(-720.0, 720.0).toDouble() / 360.0);
    final count = policy.samples.clamp(1, policy.adaptiveSampleLimit);
    if (count <= 1 || exposureMs <= 0) {
      return <double>[phaseStartMs + exposureMs / 2.0];
    }
    return <double>[
      for (var index = 0; index < count; index++)
        phaseStartMs + (exposureMs * index / (count - 1)),
    ];
  }
}
