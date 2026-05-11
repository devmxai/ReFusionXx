import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_capability.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_bus.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_mvp_toolkit.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_motion_tools.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_scene_program_tools.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_session.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_transaction.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  group('RefusionMcpMvpToolkit', () {
    late RefusionMcpCommandBus bus;
    late RefusionMcpSession session;

    setUp(() {
      bus = RefusionMcpCommandBus();
      session = RefusionMcpSession(
        id: 'session_1',
        clientName: 'test',
        clientVersion: '1.0.0',
        transport: 'stdio',
        activeProjectId: 'active',
        activeCompositionId: 'comp_1',
        timelineRevision: 7,
        grantedCapabilities: <RefusionMcpCapability>{
          RefusionMcpCapability.projectRead,
          RefusionMcpCapability.timelineRead,
          RefusionMcpCapability.previewRead,
          RefusionMcpCapability.motionWrite,
          RefusionMcpCapability.sceneWrite,
        },
      );
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: bus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{
            'projectId': 'active',
            'revision': 7,
          },
          timelineSummaryReader: () => <String, Object?>{
            'rowCount': 3,
          },
          selectionReader: () => <String, Object?>{
            'selected': <String>['clip_1'],
          },
          previewCaptureReader: (timeMs) => <String, Object?>{
            'timeMs': timeMs ?? 0,
            'resourceUri': 'refusion://preview/frame/${timeMs ?? 0}',
          },
        ),
      );
    });

    test('returns project state from command bus', () {
      final result = bus.execute(
        session: session,
        command: _command(
          type: 'refusion.get_project_state',
          capability: RefusionMcpCapability.projectRead,
        ),
        currentRevision: 7,
      );
      expect(result.ok, isTrue);
      expect(result.payload['projectId'], 'active');
    });

    test('returns preview resource uri', () {
      final result = bus.execute(
        session: session,
        command: _command(
          type: 'refusion.capture_preview_frame',
          capability: RefusionMcpCapability.previewRead,
          payload: <String, Object?>{'timeMs': 1200},
        ),
        currentRevision: 7,
      );
      expect(result.ok, isTrue);
      expect(result.resourceUris, contains('refusion://preview/frame/1200'));
    });

    test('validates scene program source through toolkit', () {
      final source = File(
        '/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/test/fixtures/refusion_scene_programs/first_generated_scene.json',
      ).readAsStringSync();
      final result = bus.execute(
        session: session,
        command: _command(
          type: 'refusion.validate_scene_program',
          capability: RefusionMcpCapability.sceneWrite,
          payload: <String, Object?>{'source': source},
        ),
        currentRevision: 7,
      );
      expect(result.ok, isTrue);
      expect(result.payload['isValid'], isTrue);
    });

    test('apply scene program returns pending transaction in dryRun', () {
      final source = File(
        '/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/test/fixtures/refusion_scene_programs/first_generated_scene.json',
      ).readAsStringSync();
      const tools = RefusionMcpSceneProgramTools();
      final authored = tools.authorSceneProgram(source: source);
      expect(authored.isValid, isTrue);
      expect(authored.project, isNotNull);
      var revision = 7;
      final toolBus = RefusionMcpCommandBus();
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: toolBus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{
            'projectId': 'active',
            'revision': revision,
          },
          timelineSummaryReader: () => <String, Object?>{'rowCount': 0},
          selectionReader: () =>
              <String, Object?>{'selected': const <String>[]},
          previewCaptureReader: (_) => <String, Object?>{},
          sceneProgramTools: tools,
          projectReader: () => authored.project!,
          rootSceneIdReader: () => authored.project!.scenes.first.id,
          sceneClipsReader: () => const <CompositionSceneClipModel>[],
          channelsReader: () => const <MotionPropertyChannelModel>[],
          textBindingsReader: () => const <MotionTextAnimationBindingModel>[],
          applySceneProgramCommit: (_) {
            revision += 1;
            return RefusionMcpApplySceneProgramCommitResult(
              revisionAfter: revision,
            );
          },
        ),
      );

      final dryRun = toolBus.execute(
        session: session,
        command: _command(
          type: 'refusion.apply_scene_program',
          capability: RefusionMcpCapability.sceneWrite,
          payload: <String, Object?>{'source': source},
        ),
        currentRevision: revision,
      );
      expect(dryRun.ok, isTrue);
      expect(dryRun.transactionId, isNotNull);
      expect(dryRun.payload['pending'], isTrue);

      final commit = toolBus.commitTransaction(
        session: session,
        transactionId: dryRun.transactionId!,
        expectedRevision: revision,
        actualRevision: revision,
      );
      expect(commit.ok, isTrue);
      expect(commit.revisionAfter, 8);
    });

    test('returns confirmation required when keyframe handler is not wired',
        () {
      final result = bus.execute(
        session: session,
        command: _command(
          type: 'refusion.keyframe_edit',
          capability: RefusionMcpCapability.motionWrite,
          payload: <String, Object?>{
            'targetId': 'node_1',
            'property': 'position.x',
          },
        ),
        currentRevision: 7,
      );
      expect(result.ok, isFalse);
      expect(result.requiresConfirmation, isTrue);
    });

    test('supports dryRun -> commit for custom keyframe mutation handler', () {
      var revision = 12;
      final toolBus = RefusionMcpCommandBus();
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: toolBus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{'revision': revision},
          timelineSummaryReader: () => <String, Object?>{'rows': 1},
          selectionReader: () => <String, Object?>{'selected': <String>[]},
          previewCaptureReader: (_) => <String, Object?>{},
          keyframeEditHandler: (_) => RefusionMcpCommandHandlingOutcome(
            summary: 'Keyframe edit prepared.',
            patchPreview: RefusionMcpPatchPreview(
              affectedObjects: <String>['node_1'],
              changedProperties: <String>['position.x'],
            ),
            commitOperation: () {
              revision += 1;
              return RefusionMcpCommitExecution(revisionAfter: revision);
            },
          ),
        ),
      );

      final dryRun = toolBus.execute(
        session: _sessionWithAllWrites(),
        command: _command(
          type: 'refusion.keyframe_edit',
          capability: RefusionMcpCapability.motionWrite,
          payload: const <String, Object?>{'targetId': 'node_1'},
        ),
        currentRevision: revision,
      );
      expect(dryRun.ok, isTrue);
      expect(dryRun.transactionId, isNotNull);

      final commit = toolBus.commitTransaction(
        session: _sessionWithAllWrites(),
        transactionId: dryRun.transactionId!,
        expectedRevision: 12,
        actualRevision: 12,
      );
      expect(commit.ok, isTrue);
      expect(commit.revisionAfter, 13);
    });

    test('uses default motion tools for keyframe_edit and persists channels',
        () {
      var revision = 20;
      var channels = <MotionPropertyChannelModel>[];
      final project = _sampleProject();
      final toolBus = RefusionMcpCommandBus();
      const toolkit = RefusionMcpMvpToolkit();
      toolkit.register(
        bus: toolBus,
        config: RefusionMcpMvpToolkitConfig(
          projectStateReader: () => <String, Object?>{'revision': revision},
          timelineSummaryReader: () => <String, Object?>{'rows': 1},
          selectionReader: () => <String, Object?>{'selected': <String>[]},
          previewCaptureReader: (_) => <String, Object?>{},
          projectReader: () => project,
          rootSceneIdReader: () => 'root-scene',
          sceneClipsReader: () => const <CompositionSceneClipModel>[],
          channelsReader: () => channels,
          textBindingsReader: () => const <MotionTextAnimationBindingModel>[],
          motionChannelsCommit: (request) {
            channels = request.channels;
            revision += 1;
            return RefusionMcpMotionChannelsCommitResult(
              revisionAfter: revision,
              summary: request.summary,
            );
          },
        ),
      );

      final dryRun = toolBus.execute(
        session: _sessionWithAllWrites(),
        command: _command(
          type: 'refusion.keyframe_edit',
          capability: RefusionMcpCapability.motionWrite,
          payload: const <String, Object?>{
            'action': 'add',
            'targetId': 'node_1',
            'property': 'position.x',
            'timeMs': 600,
            'value': 120.0,
          },
        ),
        currentRevision: revision,
      );
      expect(dryRun.ok, isTrue);
      expect(dryRun.transactionId, isNotNull);

      final commit = toolBus.commitTransaction(
        session: _sessionWithAllWrites(),
        transactionId: dryRun.transactionId!,
        expectedRevision: 20,
        actualRevision: 20,
      );
      expect(commit.ok, isTrue);
      expect(commit.revisionAfter, 21);
      expect(channels, isNotEmpty);
      expect(channels.first.definition.id, MotionPropertyCatalog.positionX.id);
    });

    test(
      'uses default motion tools for set_element_transform static values',
      () {
        var revision = 30;
        var channels = <MotionPropertyChannelModel>[];
        final project = _sampleProject();
        final toolBus = RefusionMcpCommandBus();
        const toolkit = RefusionMcpMvpToolkit();
        toolkit.register(
          bus: toolBus,
          config: RefusionMcpMvpToolkitConfig(
            projectStateReader: () => <String, Object?>{'revision': revision},
            timelineSummaryReader: () => <String, Object?>{'rows': 1},
            selectionReader: () => <String, Object?>{'selected': <String>[]},
            previewCaptureReader: (_) => <String, Object?>{},
            projectReader: () => project,
            rootSceneIdReader: () => 'root-scene',
            sceneClipsReader: () => const <CompositionSceneClipModel>[],
            channelsReader: () => channels,
            textBindingsReader: () => const <MotionTextAnimationBindingModel>[],
            motionChannelsCommit: (request) {
              channels = request.channels;
              revision += 1;
              return RefusionMcpMotionChannelsCommitResult(
                revisionAfter: revision,
                summary: request.summary,
              );
            },
          ),
        );

        final dryRun = toolBus.execute(
          session: _sessionWithAllWrites(),
          command: _command(
            type: 'refusion.set_element_transform',
            capability: RefusionMcpCapability.motionWrite,
            payload: const <String, Object?>{
              'targetId': 'node_1',
              'transform': <String, Object?>{
                'position': <String, Object?>{'x': 40.0, 'y': 80.0},
                'scale': <String, Object?>{'x': 0.9, 'y': 0.9},
                'rotationDegrees': 12.0,
                'opacity': 0.8,
              },
            },
          ),
          currentRevision: revision,
        );
        expect(dryRun.ok, isTrue);
        expect(dryRun.transactionId, isNotNull);

        final commit = toolBus.commitTransaction(
          session: _sessionWithAllWrites(),
          transactionId: dryRun.transactionId!,
          expectedRevision: 30,
          actualRevision: 30,
        );
        expect(commit.ok, isTrue);
        expect(commit.revisionAfter, 31);
        final ids = channels.map((channel) => channel.definition.id).toSet();
        expect(ids.contains(MotionPropertyCatalog.positionX.id), isTrue);
        expect(ids.contains(MotionPropertyCatalog.positionY.id), isTrue);
        expect(ids.contains(MotionPropertyCatalog.scaleX.id), isTrue);
        expect(ids.contains(MotionPropertyCatalog.scaleY.id), isTrue);
      },
    );
  });
}

RefusionMcpCommandEnvelope _command({
  required String type,
  required RefusionMcpCapability capability,
  Map<String, Object?> payload = const <String, Object?>{},
  RefusionMcpCommandMode mode = RefusionMcpCommandMode.dryRun,
  int? expectedRevision,
}) {
  return RefusionMcpCommandEnvelope(
    commandId: 'cmd_1',
    sessionId: 'session_1',
    projectId: 'active',
    type: type,
    capability: capability,
    mode: mode,
    idempotencyKey: 'turn-1',
    expectedRevision: expectedRevision,
    payload: payload,
  );
}

RefusionMcpSession _sessionWithAllWrites() {
  return RefusionMcpSession(
    id: 'session_1',
    clientName: 'test',
    clientVersion: '1.0.0',
    transport: 'stdio',
    activeProjectId: 'active',
    activeCompositionId: 'comp_1',
    timelineRevision: 12,
    grantedCapabilities: <RefusionMcpCapability>{
      RefusionMcpCapability.projectRead,
      RefusionMcpCapability.timelineRead,
      RefusionMcpCapability.previewRead,
      RefusionMcpCapability.timelineWrite,
      RefusionMcpCapability.motionWrite,
      RefusionMcpCapability.sceneWrite,
    },
  );
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
