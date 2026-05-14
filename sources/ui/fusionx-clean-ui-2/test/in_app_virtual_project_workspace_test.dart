import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/creative_transaction_contract_models.dart';
import 'package:refusion_app/features/editor/domain/models/in_app_virtual_project_workspace_models.dart';
import 'package:refusion_app/features/editor/domain/services/in_app_virtual_project_workspace.dart';

void main() {
  group('CreativeWorkspaceSnapshotBuilder', () {
    const workspace = InAppVirtualProjectWorkspace();
    const builder = CreativeWorkspaceSnapshotBuilder();

    test('story composition snapshot reports 1080x1920', () {
      final snapshot = builder.build(
        workspace,
        _request(
          layerGraph: const LayerGraphSnapshot(),
          timeline: const TimelineGraphSnapshot(),
        ),
      );

      expect(snapshot.workspace.compositionSpec.width, 1080);
      expect(snapshot.workspace.compositionSpec.height, 1920);
    });

    test('manual shape move appears in next snapshot', () {
      const baseLayer = CreativeLayerIdentity(
        layerId: 'shape-1',
        kind: 'shape',
        compositionId: 'composition-1',
        timelineTrackId: 'shape',
        zOrder: 5,
        createdBy: CreativeTransactionSource.manualUi,
        createdAtRevision: 1,
        updatedAtRevision: 1,
      );

      final first = builder.build(
        workspace,
        _request(
          layerGraph: const LayerGraphSnapshot(
            nodes: <LayerGraphNodeSnapshot>[
              LayerGraphNodeSnapshot(
                layer: baseLayer,
                x: 120,
                y: 200,
                width: 300,
                height: 300,
              ),
            ],
          ),
          timeline: const TimelineGraphSnapshot(
            clips: <TimelineClipSnapshot>[
              TimelineClipSnapshot(
                clipId: 'clip-1',
                layerId: 'shape-1',
                trackId: 'shape',
                startMs: 0,
                durationMs: 8000,
              ),
            ],
          ),
        ),
      );
      expect(first.layerGraph.nodes.single.x, 120);

      final moved = builder.build(
        workspace,
        _request(
          revision: 2,
          layerGraph: const LayerGraphSnapshot(
            nodes: <LayerGraphNodeSnapshot>[
              LayerGraphNodeSnapshot(
                layer: baseLayer,
                x: 460,
                y: 860,
                width: 300,
                height: 300,
              ),
            ],
          ),
          timeline: const TimelineGraphSnapshot(
            clips: <TimelineClipSnapshot>[
              TimelineClipSnapshot(
                clipId: 'clip-1',
                layerId: 'shape-1',
                trackId: 'shape',
                startMs: 0,
                durationMs: 8000,
              ),
            ],
          ),
        ),
      );
      expect(moved.layerGraph.nodes.single.x, 460);
      expect(moved.layerGraph.nodes.single.y, 860);
    });

    test('layer id appears in both layer graph and timeline projection', () {
      const layer = CreativeLayerIdentity(
        layerId: 'text-1',
        kind: 'text',
        compositionId: 'composition-1',
        timelineTrackId: 'text',
        zOrder: 12,
        createdBy: CreativeTransactionSource.mcpAgent,
        createdAtRevision: 1,
        updatedAtRevision: 1,
      );

      final snapshot = builder.build(
        workspace,
        _request(
          layerGraph: const LayerGraphSnapshot(
            nodes: <LayerGraphNodeSnapshot>[
              LayerGraphNodeSnapshot(
                layer: layer,
                x: 540,
                y: 320,
                width: 500,
                height: 120,
              ),
            ],
          ),
          timeline: const TimelineGraphSnapshot(
            clips: <TimelineClipSnapshot>[
              TimelineClipSnapshot(
                clipId: 'clip-text-1',
                layerId: 'text-1',
                trackId: 'text',
                startMs: 0,
                durationMs: 6000,
              ),
            ],
          ),
        ),
      );

      final graphIds =
          snapshot.layerGraph.nodes.map((node) => node.layer.layerId).toSet();
      final timelineIds =
          snapshot.timeline.clips.map((clip) => clip.layerId).toSet();
      expect(graphIds.contains('text-1'), isTrue);
      expect(timelineIds.contains('text-1'), isTrue);
    });

    test('orphan timeline clip is reported as diagnostic', () {
      final snapshot = builder.build(
        workspace,
        _request(
          layerGraph: const LayerGraphSnapshot(),
          timeline: const TimelineGraphSnapshot(
            clips: <TimelineClipSnapshot>[
              TimelineClipSnapshot(
                clipId: 'orphan-clip',
                layerId: 'missing-layer',
                trackId: 'shape',
                startMs: 0,
                durationMs: 1000,
              ),
            ],
          ),
        ),
      );

      expect(
        snapshot.workspace.diagnostics,
        contains('orphan_timeline_clip:orphan-clip'),
      );
    });
  });
}

CreativeWorkspaceSnapshotBuildRequest _request({
  int revision = 1,
  required LayerGraphSnapshot layerGraph,
  required TimelineGraphSnapshot timeline,
}) {
  return CreativeWorkspaceSnapshotBuildRequest(
    projectId: 'project-1',
    compositionId: 'composition-1',
    revision: revision,
    compositionSpec: const CompositionSpecSnapshot(
      spec: CreativeCompositionSpec(
        compositionId: 'composition-1',
        width: 1080,
        height: 1920,
        fps: 30,
        durationMs: 8000,
        currentTimeMs: 0,
        currentFrame: 0,
        coordinateSystem: 'center',
        origin: 'canvasCenter',
      ),
    ),
    layerGraph: layerGraph,
    timeline: timeline,
    selection: const SelectionSnapshot(),
    frame: const FrameSnapshotSummary(currentFrame: 0, currentTimeMs: 0),
    renderer: const RendererCapabilitySnapshot(
      rendererName: 'stage5',
    ),
  );
}
