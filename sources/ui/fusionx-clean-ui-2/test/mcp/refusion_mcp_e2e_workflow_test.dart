import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_agent_control_plane.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_bus.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_motion_tools.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_mvp_toolkit.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_resource_provider.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session_store.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_timeline_tools.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_tool_registry.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_models.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_app_bridge.dart';
import 'package:refusion_app/features/editor/presentation/mcp/refusion_mcp_json_rpc_server.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

const _e2eProjectId = 'project_e2e_1';
const _e2eCompositionId = 'composition_e2e_1';

void main() {
  group('Refusion MCP end-to-end workflow', () {
    test('completes read -> dryRun -> commit -> preview -> undo flow', () {
      var revision = 100;
      var project = _sampleProject();
      var channels = <MotionPropertyChannelModel>[];

      final commandBus = RefusionMcpCommandBus();
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: commandBus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{
            'projectId': project.id,
            'revision': revision,
          },
          timelineSummaryReader: () => <String, Object?>{
            'layerCount': project.scenes.first.layers.length,
            'revision': revision,
          },
          selectionReader: () => <String, Object?>{
            'selected': const <String>['node_1'],
          },
          previewCaptureReader: (timeMs) => <String, Object?>{
            'resourceUri': 'refusion://preview/frame/${timeMs ?? 0}',
            'timeMs': timeMs ?? 0,
          },
          projectReader: () => project,
          rootSceneIdReader: () => 'root-scene',
          sceneClipsReader: () => const <CompositionSceneClipModel>[],
          channelsReader: () => channels,
          textBindingsReader: () => const <MotionTextAnimationBindingModel>[],
          motionTools: const RefusionMcpMotionTools(),
          motionChannelsCommit: (request) {
            channels = request.channels;
            revision += 1;
            return RefusionMcpMotionChannelsCommitResult(
              revisionAfter: revision,
              summary: request.summary,
            );
          },
          timelineTools: const RefusionMcpTimelineTools(),
          timelineProjectCommit: (request) {
            project = request.project;
            revision += 1;
            return RefusionMcpTimelineProjectCommitResult(
              revisionAfter: revision,
              summary: request.summary,
            );
          },
          playheadReader: () => TimelineTime.fromMilliseconds(1200),
        ),
      );

      final resourceProvider = RefusionMcpResourceProvider(
        readers: <String, RefusionMcpResourceReader>{
          'refusion://project/active/state': () => <String, Object?>{
                'projectId': project.id,
                'revision': revision,
              },
          'refusion://timeline/active/summary': () => <String, Object?>{
                'layerCount': project.scenes.first.layers.length,
                'revision': revision,
              },
          'refusion://selection/active': () => <String, Object?>{
                'selected': const <String>['node_1'],
              },
          'refusion://preview/frame/1500': () => <String, Object?>{
                'pngBase64': 'fixture',
              },
        },
      );

      final registry = RefusionMcpToolRegistry();
      final sessionStore = RefusionMcpSessionStore();
      final controlPlane = RefusionMcpAgentControlPlane(
        commandBus: commandBus,
        toolRegistry: registry,
        sessionStore: sessionStore,
        revisionReader: () => revision,
      );
      final bridge = RefusionMcpAppBridge(
        controlPlane: controlPlane,
        sessionStore: sessionStore,
        resourceProvider: resourceProvider,
      );
      final server = RefusionMcpJsonRpcServer(
        bridge: bridge,
        toolRegistry: registry,
      );

      final open = server.handle(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'refusion/session/open',
          'params': <String, Object?>{
            'session': <String, Object?>{
              'id': 'session_e2e',
              'clientName': 'codex',
              'clientVersion': '1.0.0',
              'transport': 'stdio',
              'activeProjectId': _e2eProjectId,
              'activeCompositionId': _e2eCompositionId,
              'timelineRevision': revision,
              'capabilities': <String>[
                'project.read',
                'timeline.read',
                'timeline.write',
                'motion.write',
                'preview.read',
              ],
            },
          },
        },
      );
      expect(open['error'], isNull);

      final readProject = _callTool(
        server: server,
        id: 2,
        toolName: 'refusion.get_project_state',
        revision: revision,
      );
      expect(_isOk(readProject), isTrue);

      final readTimeline = _callTool(
        server: server,
        id: 3,
        toolName: 'refusion.get_timeline_summary',
        revision: revision,
      );
      expect(_isOk(readTimeline), isTrue);
      final baselineLayerCount =
          _payload(readTimeline)['layerCount'] as int? ?? 0;

      final dryInsert = _callTool(
        server: server,
        id: 4,
        toolName: 'refusion.insert_layer',
        revision: revision,
        mode: 'dryRun',
        payload: const <String, Object?>{
          'layerKind': 'text',
          'sceneId': 'root-scene',
          'name': 'Agent Text Layer',
        },
      );
      expect(_isOk(dryInsert), isTrue);
      final dryInsertBody = _structured(dryInsert);
      final transactionId = dryInsertBody['transactionId'] as String?;
      expect(transactionId, isNotNull);

      final commitInsert = _callTool(
        server: server,
        id: 5,
        toolName: 'refusion.commit_transaction',
        revision: revision,
        mode: 'commit',
        payload: <String, Object?>{
          'transactionId': transactionId!,
        },
      );
      expect(_isOk(commitInsert), isTrue);
      revision = _structured(commitInsert)['revisionAfter'] as int;

      final setTransformDryRun = _callTool(
        server: server,
        id: 6,
        toolName: 'refusion.set_element_transform',
        revision: revision,
        mode: 'dryRun',
        payload: const <String, Object?>{
          'targetId': 'node_1',
          'transform': <String, Object?>{
            'position': <String, Object?>{'x': 120.0, 'y': 90.0},
          },
        },
      );
      expect(_isOk(setTransformDryRun), isTrue);
      final transformTxn =
          _structured(setTransformDryRun)['transactionId'] as String?;
      expect(transformTxn, isNotNull);

      final setTransformCommit = _callTool(
        server: server,
        id: 7,
        toolName: 'refusion.commit_transaction',
        revision: revision,
        mode: 'commit',
        payload: <String, Object?>{
          'transactionId': transformTxn!,
        },
      );
      expect(_isOk(setTransformCommit), isTrue);
      revision = _structured(setTransformCommit)['revisionAfter'] as int;

      final keyframeDryRun = _callTool(
        server: server,
        id: 8,
        toolName: 'refusion.keyframe_edit',
        revision: revision,
        mode: 'dryRun',
        payload: const <String, Object?>{
          'action': 'add',
          'targetId': 'node_1',
          'property': 'position.x',
          'timeMs': 1500,
          'value': 260.0,
        },
      );
      expect(_isOk(keyframeDryRun), isTrue);
      final keyframeTxn =
          _structured(keyframeDryRun)['transactionId'] as String?;
      expect(keyframeTxn, isNotNull);

      final keyframeCommit = _callTool(
        server: server,
        id: 9,
        toolName: 'refusion.commit_transaction',
        revision: revision,
        mode: 'commit',
        payload: <String, Object?>{
          'transactionId': keyframeTxn!,
        },
      );
      expect(_isOk(keyframeCommit), isTrue);
      revision = _structured(keyframeCommit)['revisionAfter'] as int;

      final preview = _callTool(
        server: server,
        id: 10,
        toolName: 'refusion.capture_preview_frame',
        revision: revision,
        payload: const <String, Object?>{'timeMs': 1500},
      );
      expect(_isOk(preview), isTrue);
      final previewUris = (_structured(preview)['resourceUris'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[];
      expect(previewUris, contains('refusion://preview/frame/1500'));

      final undo = _callTool(
        server: server,
        id: 11,
        toolName: 'refusion.undo_transaction',
        revision: revision,
        mode: 'commit',
      );
      expect(_isOk(undo), isTrue);
      revision = _structured(undo)['revisionAfter'] as int;

      final timelineAfterUndo = _callTool(
        server: server,
        id: 12,
        toolName: 'refusion.get_timeline_summary',
        revision: revision,
      );
      expect(_isOk(timelineAfterUndo), isTrue);
      final layerCountAfterUndo =
          _payload(timelineAfterUndo)['layerCount'] as int? ?? -1;
      expect(layerCountAfterUndo, baselineLayerCount + 1);

      expect(channels, isNotEmpty);
    });
  });
}

Map<String, Object?> _callTool({
  required RefusionMcpJsonRpcServer server,
  required int id,
  required String toolName,
  required int revision,
  String mode = 'dryRun',
  Map<String, Object?> payload = const <String, Object?>{},
}) {
  return server.handle(
    <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': 'tools/call',
      'params': <String, Object?>{
        'name': toolName,
        'arguments': <String, Object?>{
          'sessionId': 'session_e2e',
          'projectId': _e2eProjectId,
          'commandId': 'cmd_$id',
          'idempotencyKey': 'e2e_$id',
          'mode': mode,
          'expectedRevision': revision,
          'payload': payload,
        },
      },
    },
  );
}

Map<String, Object?> _structured(Map<String, Object?> response) {
  final result = response['result'] as Map<String, Object?>;
  return result['structuredContent'] as Map<String, Object?>;
}

Map<String, Object?> _payload(Map<String, Object?> response) {
  final structured = _structured(response);
  return structured['payload'] as Map<String, Object?>? ??
      const <String, Object?>{};
}

bool _isOk(Map<String, Object?> response) {
  final structured = _structured(response);
  return structured['ok'] == true;
}

MotionProjectModel _sampleProject() {
  return MotionProjectModel(
    id: 'project_1',
    format: const MotionProjectFormat(
      canvasSize: MotionSize2D(width: 1080, height: 1920),
    ),
    frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
    scenes: <MotionSceneModel>[
      MotionSceneModel(
        id: 'root-scene',
        projectRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: TimelineTime.fromMilliseconds(10000),
        ),
        layers: <MotionLayerModel>[
          MotionLayerModel(
            id: 'layer_1',
            sceneId: 'root-scene',
            kind: MotionLayerKind.video,
            visibleRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(10000),
            ),
            elements: <MotionElementModel>[
              MotionElementModel(
                id: 'node_1',
                layerId: 'layer_1',
                kind: MotionElementKind.videoClip,
                localRange: TimelineTimeRange(
                  start: TimelineTime.zero,
                  endExclusive: TimelineTime.fromMilliseconds(10000),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
