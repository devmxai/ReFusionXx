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

    for (final surface in program.surfaces) {
      final surfaceBlockers = <String>[...surface.blockers];
      final surfaceDiagnostics = <String>[];
      String? sourceNodeId;
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
            'transitionRole': surface.transitionRole.name,
            'sourceKind': surface.sourceKind.name,
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
          effectNodeIds: effectNodeIds,
          transitionNodeId: transitionNodeId,
          compositeNodeId: compositeNodeId,
          transitionRole: surface.transitionRole,
          blockers: surfaceBlockers,
        ),
      );
    }

    final outputNodeId = 'output:${program.time.renderMode.name}';
    final orderedComposites =
        bindings.map((entry) => entry.compositeNodeId).toList(
              growable: false,
            );
    nodes.add(
      MasterRenderGraphNode(
        id: outputNodeId,
        family: MasterRenderGraphNodeFamily.outputSurface,
        targetId: outputNodeId,
        inputNodeIds: orderedComposites,
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
    diagnostics.add('master_render_graph_revision:$revision');
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
}
