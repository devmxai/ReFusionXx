import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/composition_scene_clip_models.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_models.dart';
import '../models/professional_motion_text_models.dart';
import 'refusion_mcp_command.dart';
import 'refusion_mcp_command_bus.dart';
import 'refusion_mcp_motion_tools.dart';
import 'refusion_mcp_scene_program_tools.dart';
import 'refusion_mcp_timeline_tools.dart';
import 'refusion_mcp_transaction.dart';
import '../services/refusion_scene_program_authoring_service.dart';
import '../services/scene_program_apply_transaction.dart';

typedef RefusionMcpStateReader = Map<String, Object?> Function();
typedef RefusionMcpCommandStatusReader = Map<String, Object?> Function(
  String? commandId,
);
typedef RefusionMcpPreviewCaptureReader = Map<String, Object?> Function(
  int? timeMs,
);
typedef RefusionMcpSecurityProfileReader = Map<String, Object?> Function();
typedef RefusionMcpHostCompatibilityReader = Map<String, Object?> Function();
typedef RefusionMcpLaunchReadinessReader = Map<String, Object?> Function(
  Map<String, Object?> payload,
);
typedef RefusionMcpCreativeLibraryDiscoveryReader = Map<String, Object?>
    Function({
  required String toolName,
  Map<String, Object?> payload,
});
typedef RefusionMcpProjectReader = MotionProjectModel Function();
typedef RefusionMcpRootSceneIdReader = String Function();
typedef RefusionMcpSceneClipsReader = List<CompositionSceneClipModel>
    Function();
typedef RefusionMcpChannelsReader = List<MotionPropertyChannelModel> Function();
typedef RefusionMcpTextBindingsReader = List<MotionTextAnimationBindingModel>
    Function();

@immutable
class RefusionMcpApplySceneProgramCommitRequest {
  const RefusionMcpApplySceneProgramCommitRequest({
    required this.authoringResult,
    required this.applyResult,
    required this.command,
  });

  final ReFusionSceneProgramAuthoringResult authoringResult;
  final SceneProgramApplyTransactionResult applyResult;
  final RefusionMcpCommandEnvelope command;
}

@immutable
class RefusionMcpApplySceneProgramCommitResult {
  const RefusionMcpApplySceneProgramCommitResult({
    required this.revisionAfter,
    this.summary,
    this.affectedObjects = const <String>[],
    this.diagnostics = const <String>[],
  });

  final int revisionAfter;
  final String? summary;
  final List<String> affectedObjects;
  final List<String> diagnostics;
}

typedef RefusionMcpApplySceneProgramCommit
    = RefusionMcpApplySceneProgramCommitResult Function(
        RefusionMcpApplySceneProgramCommitRequest request);
typedef RefusionMcpMutationCommandHandler = RefusionMcpCommandHandlingOutcome
    Function(RefusionMcpCommandEnvelope command);

@immutable
class RefusionMcpMvpToolkitConfig {
  const RefusionMcpMvpToolkitConfig({
    required this.projectStateReader,
    required this.timelineSummaryReader,
    required this.selectionReader,
    required this.previewCaptureReader,
    this.securityProfileReader,
    this.hostCompatibilityReader,
    this.launchReadinessReader,
    this.creativeLibraryDiscoveryReader,
    this.commandStatusReader,
    this.sceneProgramTools = const RefusionMcpSceneProgramTools(),
    this.projectReader,
    this.rootSceneIdReader,
    this.sceneClipsReader,
    this.channelsReader,
    this.textBindingsReader,
    this.applySceneProgramCommit,
    this.applyMotionPatchHandler,
    this.keyframeEditHandler,
    this.setElementTransformHandler,
    this.motionTools = const RefusionMcpMotionTools(),
    this.motionChannelsCommit,
    this.playheadReader,
    this.timelineTools = const RefusionMcpTimelineTools(),
    this.insertLayerHandler,
    this.splitAtPlayheadHandler,
    this.trimLayerHandler,
    this.moveLayerHandler,
    this.deleteLayerHandler,
    this.timelineProjectCommit,
  });

  final RefusionMcpStateReader projectStateReader;
  final RefusionMcpStateReader timelineSummaryReader;
  final RefusionMcpStateReader selectionReader;
  final RefusionMcpPreviewCaptureReader previewCaptureReader;
  final RefusionMcpSecurityProfileReader? securityProfileReader;
  final RefusionMcpHostCompatibilityReader? hostCompatibilityReader;
  final RefusionMcpLaunchReadinessReader? launchReadinessReader;
  final RefusionMcpCreativeLibraryDiscoveryReader?
      creativeLibraryDiscoveryReader;
  final RefusionMcpCommandStatusReader? commandStatusReader;
  final RefusionMcpSceneProgramTools sceneProgramTools;
  final RefusionMcpProjectReader? projectReader;
  final RefusionMcpRootSceneIdReader? rootSceneIdReader;
  final RefusionMcpSceneClipsReader? sceneClipsReader;
  final RefusionMcpChannelsReader? channelsReader;
  final RefusionMcpTextBindingsReader? textBindingsReader;
  final RefusionMcpApplySceneProgramCommit? applySceneProgramCommit;
  final RefusionMcpMutationCommandHandler? applyMotionPatchHandler;
  final RefusionMcpMutationCommandHandler? keyframeEditHandler;
  final RefusionMcpMutationCommandHandler? setElementTransformHandler;
  final RefusionMcpMotionTools motionTools;
  final RefusionMcpMotionChannelsCommit? motionChannelsCommit;
  final RefusionMcpTimelinePlayheadReader? playheadReader;
  final RefusionMcpTimelineTools timelineTools;
  final RefusionMcpMutationCommandHandler? insertLayerHandler;
  final RefusionMcpMutationCommandHandler? splitAtPlayheadHandler;
  final RefusionMcpMutationCommandHandler? trimLayerHandler;
  final RefusionMcpMutationCommandHandler? moveLayerHandler;
  final RefusionMcpMutationCommandHandler? deleteLayerHandler;
  final RefusionMcpTimelineProjectCommit? timelineProjectCommit;
}

class RefusionMcpMvpToolkit {
  const RefusionMcpMvpToolkit();

  void register({
    required RefusionMcpCommandBus bus,
    required RefusionMcpMvpToolkitConfig config,
  }) {
    bus.registerHandler(
      commandType: 'refusion.get_active_context',
      handler: (_) {
        final projectState = config.projectStateReader();
        final projectId =
            (projectState['projectId'] as String?)?.trim().isNotEmpty == true
                ? projectState['projectId'] as String
                : 'active';
        final revision = projectState['revision'] is num
            ? (projectState['revision'] as num).round()
            : 0;
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Active context loaded.',
          payload: <String, Object?>{
            'project': <String, Object?>{
              'id': projectId,
              'name': projectState['projectName'] ?? 'Active Project',
              'revision': revision,
            },
            'composition': <String, Object?>{
              'id': projectState['compositionId'] ?? 'active-composition',
              'name': projectState['compositionName'] ?? 'Composition 1',
            },
            'timeline': <String, Object?>{
              'id': projectState['timelineId'] ?? 'main',
              'playheadMs': projectState['playheadMs'] ?? 0,
            },
            'liveEditor': const <String, Object?>{
              'online': true,
            },
          },
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.get_project_state',
      handler: (_) {
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Project state loaded.',
          payload: config.projectStateReader(),
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.get_composition_spec',
      handler: (_) {
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Composition spec loaded.',
          payload: _buildCompositionSpecPayload(config),
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.get_canvas_metadata',
      handler: (_) {
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Canvas metadata loaded.',
          payload: _buildCanvasMetadataPayload(config),
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.get_visual_layout_summary',
      handler: (_) {
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Visual layout summary loaded.',
          payload: _buildVisualLayoutSummaryPayload(config),
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.get_spatial_scene_snapshot',
      handler: (context) {
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Spatial scene snapshot loaded.',
          payload: _buildSpatialSceneSnapshotPayload(
            config,
            context.command.payload,
          ),
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.get_element_geometry',
      handler: (context) {
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Element geometry loaded.',
          payload: _buildElementGeometryPayload(
            config,
            context.command.payload,
          ),
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.get_project_snapshot',
      handler: (_) {
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Project snapshot loaded.',
          payload: _buildProjectSnapshotPayload(config),
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.get_timeline_graph',
      handler: (_) {
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Timeline graph loaded.',
          payload: _buildTimelineGraphPayload(config),
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.evaluate_frame',
      handler: (context) {
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Frame evaluated.',
          payload: _buildFrameEvaluationPayload(
            config,
            context.command.payload,
          ),
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.get_timeline_summary',
      handler: (_) {
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Timeline summary loaded.',
          payload: config.timelineSummaryReader(),
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.get_selection',
      handler: (_) {
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Selection loaded.',
          payload: config.selectionReader(),
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.get_command_status',
      handler: (context) {
        final commandId = context.command.payload['commandId'] as String?;
        final defaultStatus = <String, Object?>{
          'commandId': commandId,
          'status': 'unknown',
          'message':
              'No command status reader is wired in this runtime profile.',
        };
        final payload =
            config.commandStatusReader?.call(commandId) ?? defaultStatus;
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Command status loaded.',
          payload: payload,
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.capture_preview_frame',
      handler: (context) {
        final timeMs = _readInt(context.command.payload['timeMs']);
        final payload = config.previewCaptureReader(timeMs);
        final resourceUri = payload['resourceUri'];
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Preview frame captured.',
          payload: payload,
          resourceUris:
              resourceUri is String ? <String>[resourceUri] : const <String>[],
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.create_project',
      handler: (context) {
        final requestedName =
            (context.command.payload['projectName'] as String?)?.trim();
        return RefusionMcpCommandHandlingOutcome(
          summary: context.command.mode == RefusionMcpCommandMode.commit
              ? 'Project context prepared.'
              : 'Project context preview is ready.',
          payload: <String, Object?>{
            'projectName': requestedName ?? 'Untitled Project',
            'note':
                'Runtime create_project is currently context-scoped. Supabase MCP cloud path should own persistent project creation.',
          },
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.get_security_profile',
      handler: (_) {
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Security profile loaded.',
          payload: config.securityProfileReader?.call() ??
              <String, Object?>{
                'pairing': <String, Object?>{
                  'required': false,
                },
                'limits': <String, Object?>{
                  'maxToolPayloadBytes': 0,
                  'maxCallsPerMinutePerSession': 0,
                },
                'restrictedCapabilities': <String>[
                  'filesystem.read',
                  'filesystem.write',
                  'export.start',
                  'debug.diagnostics',
                ],
              },
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.get_host_compatibility',
      handler: (_) {
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Host compatibility profile loaded.',
          payload: config.hostCompatibilityReader?.call() ??
              <String, Object?>{
                'claude': <String, Object?>{
                  'supported': true,
                  'transport': 'stdio',
                },
                'codex': <String, Object?>{
                  'supported': true,
                  'transport': 'stdio',
                },
                'chatgpt': <String, Object?>{
                  'supported': true,
                  'requiresRemoteDomain': true,
                  'requiredTransport': 'streamable-http',
                  'domainSetupPath': 'ChatGPT > Settings > Apps',
                },
              },
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.get_launch_readiness',
      handler: (context) {
        final reader = config.launchReadinessReader;
        if (reader == null) {
          return RefusionMcpCommandHandlingOutcome(
            summary: 'Launch readiness evaluator is not wired.',
            payload: const <String, Object?>{
              'ok': false,
              'error': 'launch_readiness_not_wired',
              'message':
                  'RefusionMcpMvpToolkitConfig.launchReadinessReader is required for refusion.get_launch_readiness.',
            },
          );
        }
        final payload = reader(context.command.payload);
        final isOk = payload['ok'] == true;
        return RefusionMcpCommandHandlingOutcome(
          summary: isOk
              ? 'Launch readiness evaluated.'
              : 'Launch readiness evaluation returned issues.',
          payload: payload,
        );
      },
    );
    _registerCreativeDiscoveryTool(
      bus: bus,
      commandType: 'refusion.list_components',
      config: config,
    );
    _registerCreativeDiscoveryTool(
      bus: bus,
      commandType: 'refusion.list_effects',
      config: config,
    );
    _registerCreativeDiscoveryTool(
      bus: bus,
      commandType: 'refusion.list_motion_recipes',
      config: config,
    );
    _registerCreativeDiscoveryTool(
      bus: bus,
      commandType: 'refusion.list_templates',
      config: config,
    );
    _registerCreativeDiscoveryTool(
      bus: bus,
      commandType: 'refusion.list_icons',
      config: config,
    );
    _registerCreativeDiscoveryTool(
      bus: bus,
      commandType: 'refusion.describe_component',
      config: config,
    );
    _registerCreativeDiscoveryTool(
      bus: bus,
      commandType: 'refusion.describe_effect',
      config: config,
    );
    _registerCreativeDiscoveryTool(
      bus: bus,
      commandType: 'refusion.describe_motion_recipe',
      config: config,
    );
    _registerCreativeDiscoveryTool(
      bus: bus,
      commandType: 'refusion.describe_template',
      config: config,
    );
    _registerCreativeDiscoveryTool(
      bus: bus,
      commandType: 'refusion.describe_icon',
      config: config,
    );
    bus.registerHandler(
      commandType: 'refusion.validate_scene_program',
      handler: (context) {
        final source = _readSource(context.command.payload);
        if (source == null) {
          return RefusionMcpCommandHandlingOutcome(
            summary: 'Scene program source is missing.',
            requiresConfirmation: true,
          );
        }
        final fileName = context.command.payload['fileName'] as String?;
        final result = config.sceneProgramTools.validateSceneProgram(
          source: source,
          fileName: fileName,
        );
        return RefusionMcpCommandHandlingOutcome(
          summary: result.isValid
              ? 'Scene program validated.'
              : 'Scene program validation returned issues.',
          diagnostics: result.issues
              .map((issue) => '${issue.severity.name}: ${issue.message}')
              .toList(growable: false),
          payload: <String, Object?>{
            'isValid': result.isValid,
            'issueCount': result.issues.length,
            'hasProgram': result.program != null,
          },
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.author_scene_program',
      handler: (context) {
        final source = _readSource(context.command.payload);
        if (source == null) {
          return RefusionMcpCommandHandlingOutcome(
            summary: 'Scene program source is missing.',
            requiresConfirmation: true,
          );
        }
        final fileName = context.command.payload['fileName'] as String?;
        final projectId = context.command.payload['projectId'] as String?;
        final sceneId = context.command.payload['sceneId'] as String?;
        final canvasWidth = _readDouble(context.command.payload['canvasWidth']);
        final canvasHeight =
            _readDouble(context.command.payload['canvasHeight']);
        final result = config.sceneProgramTools.authorSceneProgram(
          source: source,
          fileName: fileName,
          projectId: projectId,
          sceneId: sceneId,
          canvasSize: MotionSize2D(
            width: canvasWidth ?? 1080,
            height: canvasHeight ?? 1920,
          ),
        );
        return RefusionMcpCommandHandlingOutcome(
          summary: result.isValid
              ? 'Scene program authored.'
              : 'Scene authoring returned issues.',
          diagnostics: result.issues
              .map((issue) => '${issue.severity.name}: ${issue.message}')
              .toList(growable: false),
          payload: <String, Object?>{
            'isValid': result.isValid,
            'issueCount': result.issues.length,
            'hasProgram': result.program != null,
            'hasProject': result.project != null,
          },
        );
      },
    );
    bus.registerHandler(
      commandType: 'refusion.apply_scene_program',
      handler: (context) {
        final source = _readSource(context.command.payload);
        if (source == null) {
          return RefusionMcpCommandHandlingOutcome(
            summary: 'Scene program source is missing.',
            requiresConfirmation: true,
          );
        }
        if (!_canApplySceneProgram(config)) {
          return RefusionMcpCommandHandlingOutcome(
            summary: 'Scene apply commit path is not wired in this runtime.',
            requiresConfirmation: true,
          );
        }
        final fileName = context.command.payload['fileName'] as String?;
        final projectId = context.command.payload['projectId'] as String?;
        final sceneId = context.command.payload['sceneId'] as String?;
        final canvasWidth = _readDouble(context.command.payload['canvasWidth']);
        final canvasHeight =
            _readDouble(context.command.payload['canvasHeight']);
        final startMs = _readInt(context.command.payload['startTimeMs']) ?? 0;
        final clipId = context.command.payload['clipId'] as String?;
        final sourceSceneId =
            context.command.payload['sourceSceneId'] as String?;
        final clipName = context.command.payload['clipName'] as String?;

        final authoringResult = config.sceneProgramTools.authorSceneProgram(
          source: source,
          fileName: fileName,
          projectId: projectId,
          sceneId: sceneId,
          canvasSize: MotionSize2D(
            width: canvasWidth ?? 1080,
            height: canvasHeight ?? 1920,
          ),
        );
        if (!authoringResult.isValid || authoringResult.project == null) {
          return RefusionMcpCommandHandlingOutcome(
            summary: 'Scene authoring failed before apply.',
            diagnostics: authoringResult.issues
                .map((issue) => '${issue.severity.name}: ${issue.message}')
                .toList(growable: false),
            payload: <String, Object?>{
              'isValid': false,
              'issueCount': authoringResult.issues.length,
            },
          );
        }

        final applyRequest = SceneProgramApplyTransactionRequest(
          baseProject: config.projectReader!.call(),
          authoringResult: authoringResult,
          rootSceneId: config.rootSceneIdReader!.call(),
          startTime: TimelineTime.fromMilliseconds(startMs),
          clipId: clipId,
          sourceSceneId: sourceSceneId,
          clipName: clipName,
          existingSceneClips: config.sceneClipsReader!.call(),
          existingChannels: config.channelsReader!.call(),
          existingTextAnimationBindings: config.textBindingsReader!.call(),
        );

        final dryRunApplyResult =
            config.sceneProgramTools.applySceneProgram(applyRequest);
        if (dryRunApplyResult == null) {
          return RefusionMcpCommandHandlingOutcome(
            summary: 'Scene apply transaction failed preflight.',
            diagnostics: authoringResult.issues
                .map((issue) => '${issue.severity.name}: ${issue.message}')
                .toList(growable: false),
            payload: <String, Object?>{
              'isValid': false,
              'issueCount': authoringResult.issues.length,
            },
          );
        }

        return RefusionMcpCommandHandlingOutcome(
          summary: 'Scene apply is ready to commit.',
          patchPreview: RefusionMcpPatchPreview(
            affectedObjects: <String>[
              dryRunApplyResult.sceneClip.id,
              dryRunApplyResult.sourceScene.id,
              dryRunApplyResult.rootScene.id,
            ],
            changedProperties: const <String>[
              'sceneClips',
              'channels',
              'textAnimationBindings',
              'project',
            ],
            diagnostics: authoringResult.issues
                .map((issue) => '${issue.severity.name}: ${issue.message}')
                .toList(growable: false),
          ),
          commitOperation: () {
            final commitApplyResult =
                config.sceneProgramTools.applySceneProgram(applyRequest);
            if (commitApplyResult == null) {
              throw StateError('Scene apply transaction failed on commit.');
            }
            final commitResult = config.applySceneProgramCommit!.call(
              RefusionMcpApplySceneProgramCommitRequest(
                authoringResult: authoringResult,
                applyResult: commitApplyResult,
                command: context.command,
              ),
            );
            return RefusionMcpCommitExecution(
              revisionAfter: commitResult.revisionAfter,
              summary: commitResult.summary,
            );
          },
          diagnostics: authoringResult.issues
              .map((issue) => '${issue.severity.name}: ${issue.message}')
              .toList(growable: false),
          payload: <String, Object?>{
            'isValid': true,
            'issueCount': authoringResult.issues.length,
            'sceneClipId': dryRunApplyResult.sceneClip.id,
          },
        );
      },
    );
    _registerMutationHandler(
      bus: bus,
      commandType: 'refusion.apply_motion_patch',
      mutationHandler: config.applyMotionPatchHandler,
      defaultHandler: (command) => _defaultMotionMutationHandler(
        command: command,
        commandType: 'refusion.apply_motion_patch',
        config: config,
      ),
    );
    _registerMutationHandler(
      bus: bus,
      commandType: 'refusion.keyframe_edit',
      mutationHandler: config.keyframeEditHandler,
      defaultHandler: (command) => _defaultMotionMutationHandler(
        command: command,
        commandType: 'refusion.keyframe_edit',
        config: config,
      ),
    );
    _registerMutationHandler(
      bus: bus,
      commandType: 'refusion.set_element_transform',
      mutationHandler: config.setElementTransformHandler,
      defaultHandler: (command) => _defaultMotionMutationHandler(
        command: command,
        commandType: 'refusion.set_element_transform',
        config: config,
      ),
    );
    _registerMutationHandler(
      bus: bus,
      commandType: 'refusion.insert_layer',
      mutationHandler: config.insertLayerHandler,
      defaultHandler: (command) => _defaultTimelineMutationHandler(
        command: command,
        config: config,
      ),
    );
    _registerMutationHandler(
      bus: bus,
      commandType: 'refusion.split_at_playhead',
      mutationHandler: config.splitAtPlayheadHandler,
      defaultHandler: (command) => _defaultTimelineMutationHandler(
        command: command,
        config: config,
      ),
    );
    _registerMutationHandler(
      bus: bus,
      commandType: 'refusion.trim_layer',
      mutationHandler: config.trimLayerHandler,
      defaultHandler: (command) => _defaultTimelineMutationHandler(
        command: command,
        config: config,
      ),
    );
    _registerMutationHandler(
      bus: bus,
      commandType: 'refusion.move_layer',
      mutationHandler: config.moveLayerHandler,
      defaultHandler: (command) => _defaultTimelineMutationHandler(
        command: command,
        config: config,
      ),
    );
    _registerMutationHandler(
      bus: bus,
      commandType: 'refusion.delete_layer',
      mutationHandler: config.deleteLayerHandler,
      defaultHandler: (command) => _defaultTimelineMutationHandler(
        command: command,
        config: config,
      ),
    );
  }
}

Map<String, Object?> _buildCompositionSpecPayload(
  RefusionMcpMvpToolkitConfig config,
) {
  final state = config.projectStateReader();
  final project = config.projectReader?.call();
  final stateProjectId = _normalizedProjectIdentity(_readString(state['projectId']));
  final stateCompositionId =
      _normalizedCompositionIdentity(_readString(state['compositionId']));
  final projectId = _normalizedProjectIdentity(project?.id) ?? stateProjectId;
  final compositionId = _normalizedCompositionIdentity(_firstScene(project)?.id) ??
      stateCompositionId;
  final hasActiveComposition = projectId != null && compositionId != null;
  final canvasSize = project?.format.canvasSize;
  final canvasWidth = canvasSize?.width.round() ??
      _readInt(state['canvasWidth']) ??
      _readInt(state['width']) ??
      1080;
  final canvasHeight = canvasSize?.height.round() ??
      _readInt(state['canvasHeight']) ??
      _readInt(state['height']) ??
      1920;
  final fps = project?.frameRate.framesPerSecond.round() ??
      _readInt(state['fps']) ??
      30;
  final durationMs = project?.durationTime.inMilliseconds ??
      _readInt(state['durationMs']) ??
      0;
  final playheadMs =
      _readInt(state['playheadMs']) ?? _readInt(state['currentTimeMs']) ?? 0;
  final currentFrame = fps > 0 ? ((playheadMs / 1000.0) * fps).round() : 0;
  return <String, Object?>{
    'projectId': projectId ?? '',
    'compositionId': compositionId ?? '',
    'hasActiveComposition': hasActiveComposition,
    'width': canvasWidth,
    'height': canvasHeight,
    'canvasWidth': canvasWidth,
    'canvasHeight': canvasHeight,
    'durationMs': durationMs,
    'fps': fps,
    'currentTimeMs': playheadMs,
    'currentFrame': currentFrame,
    'coordinateSystem': 'center-origin',
    'origin': 'center',
    'aspectRatio': canvasHeight == 0 ? null : canvasWidth / canvasHeight,
  };
}

Map<String, Object?> _buildCanvasMetadataPayload(
  RefusionMcpMvpToolkitConfig config,
) {
  final spec = _buildCompositionSpecPayload(config);
  final width = _readInt(spec['width']) ?? 1080;
  final height = _readInt(spec['height']) ?? 1920;
  final halfWidth = width / 2.0;
  final halfHeight = height / 2.0;
  return <String, Object?>{
    ...spec,
    'canvas': <String, Object?>{
      'width': width,
      'height': height,
      'durationMs': spec['durationMs'],
      'fps': spec['fps'],
      'coordinateSystem': spec['coordinateSystem'],
      'origin': spec['origin'],
    },
    'safeZones': <String, Object?>{
      'title': <String, Object?>{
        'top': (height * 0.1).round(),
        'bottom': (height * 0.1).round(),
        'left': (width * 0.06).round(),
        'right': (width * 0.06).round(),
      },
      'action': <String, Object?>{
        'top': (height * 0.05).round(),
        'bottom': (height * 0.05).round(),
        'left': (width * 0.03).round(),
        'right': (width * 0.03).round(),
      },
    },
    'anchors': <String, Object?>{
      'topLeft': <String, Object?>{'x': -halfWidth, 'y': -halfHeight},
      'topCenter': <String, Object?>{'x': 0.0, 'y': -halfHeight},
      'topRight': <String, Object?>{'x': halfWidth, 'y': -halfHeight},
      'centerLeft': <String, Object?>{'x': -halfWidth, 'y': 0.0},
      'center': <String, Object?>{'x': 0.0, 'y': 0.0},
      'centerRight': <String, Object?>{'x': halfWidth, 'y': 0.0},
      'bottomLeft': <String, Object?>{'x': -halfWidth, 'y': halfHeight},
      'bottomCenter': <String, Object?>{'x': 0.0, 'y': halfHeight},
      'bottomRight': <String, Object?>{'x': halfWidth, 'y': halfHeight},
    },
  };
}

Map<String, Object?> _buildVisualLayoutSummaryPayload(
  RefusionMcpMvpToolkitConfig config,
) {
  final project = config.projectReader?.call();
  final spec = _buildCompositionSpecPayload(config);
  final layers = project == null
      ? const <Map<String, Object?>>[]
      : _layerSummariesForProject(project);
  return <String, Object?>{
    ...spec,
    'layerCount': layers.length,
    'layers': layers,
    'summary':
        'Canvas ${spec['width']}x${spec['height']} with ${layers.length} layer(s).',
  };
}

Map<String, Object?> _buildSpatialSceneSnapshotPayload(
  RefusionMcpMvpToolkitConfig config,
  Map<String, Object?> payload,
) {
  final metadata = _buildCanvasMetadataPayload(config);
  final layoutSummary = _buildVisualLayoutSummaryPayload(config);
  final geometry = _buildElementGeometryPayload(config, payload);
  final projectSnapshot = _buildProjectSnapshotPayload(config);
  final timelineGraph = _buildTimelineGraphPayload(config);
  final frame = _buildFrameEvaluationPayload(config, payload);
  return <String, Object?>{
    'projectId': metadata['projectId'],
    'compositionId': metadata['compositionId'],
    'revision': projectSnapshot['revision'],
    'canvasMetadata': metadata,
    'visualLayoutSummary': layoutSummary,
    'primaryElementGeometry': geometry,
    'projectSnapshot': projectSnapshot,
    'timelineGraph': timelineGraph,
    'frameEvaluation': frame,
    'snapshotId':
        '${metadata['projectId'] ?? 'project'}:${metadata['compositionId'] ?? 'composition'}:${projectSnapshot['revision'] ?? 0}:${frame['timeMs'] ?? 0}',
    'coordinateContract': const <String, Object?>{
      'canonical': 'centerOrigin',
      'absolute': 'topLeftAbsolute',
      'unit': 'px',
    },
  };
}

Map<String, Object?> _buildProjectSnapshotPayload(
  RefusionMcpMvpToolkitConfig config,
) {
  final project = config.projectReader?.call();
  final spec = _buildCompositionSpecPayload(config);
  return <String, Object?>{
    ...spec,
    'revision': config.projectStateReader()['revision'],
    'layers': project == null
        ? const <Map<String, Object?>>[]
        : _layerSummariesForProject(project),
    'selection': config.selectionReader(),
  };
}

Map<String, Object?> _buildTimelineGraphPayload(
  RefusionMcpMvpToolkitConfig config,
) {
  final project = config.projectReader?.call();
  final spec = _buildCompositionSpecPayload(config);
  return <String, Object?>{
    ...spec,
    'timeline': config.timelineSummaryReader(),
    'tracks': project == null
        ? const <Map<String, Object?>>[]
        : project.scenes
            .map(
              (scene) => <String, Object?>{
                'sceneId': scene.id,
                'startMs': scene.projectRange.start.inMilliseconds,
                'durationMs': scene.durationTime.inMilliseconds,
                'layers': scene.layers
                    .map(
                      (layer) => <String, Object?>{
                        'layerId': layer.id,
                        'trackKind': layer.kind.name,
                        'startMs': layer.visibleRange.start.inMilliseconds,
                        'durationMs':
                            layer.visibleRange.duration.inMilliseconds,
                        'zIndex': layer.zIndex,
                      },
                    )
                    .toList(growable: false),
              },
            )
            .toList(growable: false),
  };
}

Map<String, Object?> _buildFrameEvaluationPayload(
  RefusionMcpMvpToolkitConfig config,
  Map<String, Object?> payload,
) {
  final project = config.projectReader?.call();
  final spec = _buildCompositionSpecPayload(config);
  final timeMs =
      _readInt(payload['timeMs']) ?? _readInt(spec['currentTimeMs']) ?? 0;
  final visibleLayers = project == null
      ? const <Map<String, Object?>>[]
      : _layerSummariesForProject(project).where((layer) {
          final startMs = _readInt(layer['startMs']) ?? 0;
          final durationMs = _readInt(layer['durationMs']) ?? 0;
          return timeMs >= startMs && timeMs < startMs + durationMs;
        }).toList(growable: false);
  return <String, Object?>{
    ...spec,
    'timeMs': timeMs,
    'visibleLayerCount': visibleLayers.length,
    'visibleLayers': visibleLayers,
    'frameEvaluated': true,
  };
}

Map<String, Object?> _buildElementGeometryPayload(
  RefusionMcpMvpToolkitConfig config,
  Map<String, Object?> payload,
) {
  final project = config.projectReader?.call();
  final spec = _buildCanvasMetadataPayload(config);
  final targetId = _firstString(<Object?>[
    payload['layerId'],
    payload['elementId'],
    payload['targetLayerId'],
    payload['clipId'],
  ]);
  if (project == null || targetId == null) {
    return <String, Object?>{
      ...spec,
      'found': false,
      'targetId': targetId,
    };
  }
  final target = _findGeometryTarget(project, targetId);
  if (target == null) {
    return <String, Object?>{
      ...spec,
      'found': false,
      'targetId': targetId,
    };
  }
  final layer = target.layer;
  final element = target.element;
  final width = (_readInt(spec['width']) ?? 1080).toDouble();
  final height = (_readInt(spec['height']) ?? 1920).toDouble();
  return <String, Object?>{
    ...spec,
    'found': true,
    'layerId': layer.id,
    'elementId': element?.id,
    'kind': element?.kind.name ?? layer.kind.name,
    'layerKind': layer.kind.name,
    'name': element?.name ?? layer.name,
    'worldBounds': <String, Object?>{
      'x': 0.0,
      'y': 0.0,
      'width': width,
      'height': height,
      'rotation': 0.0,
      'scale': 1.0,
    },
    'anchor': const <String, Object?>{'x': 0.5, 'y': 0.5},
    'intrinsicSize': <String, Object?>{
      'width': width,
      'height': height,
    },
    'visibleRange': <String, Object?>{
      'startMs': layer.visibleRange.start.inMilliseconds,
      'durationMs': layer.visibleRange.duration.inMilliseconds,
    },
  };
}

List<Map<String, Object?>> _layerSummariesForProject(
    MotionProjectModel project) {
  return project.scenes
      .expand(
        (scene) => scene.layers.map(
          (layer) => <String, Object?>{
            'id': layer.id,
            'layerId': layer.id,
            'sceneId': scene.id,
            'kind': layer.kind.name,
            'name': layer.name,
            'zIndex': layer.zIndex,
            'startMs': layer.visibleRange.start.inMilliseconds,
            'durationMs': layer.visibleRange.duration.inMilliseconds,
            'elements': layer.elements
                .map(
                  (element) => <String, Object?>{
                    'id': element.id,
                    'elementId': element.id,
                    'kind': element.kind.name,
                    'name': element.name,
                    'shapeKind': element.shapeKind?.name,
                    'text': element.sourceBinding?.label,
                    'startMs': element.localRange.start.inMilliseconds,
                    'durationMs': element.localRange.duration.inMilliseconds,
                  },
                )
                .toList(growable: false),
          },
        ),
      )
      .toList(growable: false);
}

MotionSceneModel? _firstScene(MotionProjectModel? project) {
  if (project == null || project.scenes.isEmpty) {
    return null;
  }
  return project.scenes.first;
}

_GeometryTarget? _findGeometryTarget(
    MotionProjectModel project, String targetId) {
  for (final scene in project.scenes) {
    for (final layer in scene.layers) {
      if (layer.id == targetId) {
        return _GeometryTarget(layer: layer);
      }
      for (final element in layer.elements) {
        if (element.id == targetId) {
          return _GeometryTarget(layer: layer, element: element);
        }
      }
    }
  }
  return null;
}

class _GeometryTarget {
  const _GeometryTarget({
    required this.layer,
    this.element,
  });

  final MotionLayerModel layer;
  final MotionElementModel? element;
}

String? _firstString(Iterable<Object?> values) {
  for (final value in values) {
    final string = _readString(value);
    if (string != null) {
      return string;
    }
  }
  return null;
}

String? _readString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

String? _normalizedProjectIdentity(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  final lower = normalized.toLowerCase();
  if (const <String>{
    'active',
    'default',
    'motion-project',
    'project',
  }.contains(lower)) {
    return null;
  }
  return normalized;
}

String? _normalizedCompositionIdentity(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  final lower = normalized.toLowerCase();
  if (const <String>{
    'active-composition',
    'active',
    'scene-main',
    'comp_1',
    'main',
    'default',
  }.contains(lower)) {
    return null;
  }
  return normalized;
}

void _registerMutationHandler({
  required RefusionMcpCommandBus bus,
  required String commandType,
  required RefusionMcpMutationCommandHandler? mutationHandler,
  required RefusionMcpMutationCommandHandler defaultHandler,
}) {
  bus.registerHandler(
    commandType: commandType,
    handler: (context) {
      if (mutationHandler == null) {
        return defaultHandler(context.command);
      }
      return mutationHandler(context.command);
    },
  );
}

void _registerCreativeDiscoveryTool({
  required RefusionMcpCommandBus bus,
  required String commandType,
  required RefusionMcpMvpToolkitConfig config,
}) {
  bus.registerHandler(
    commandType: commandType,
    handler: (context) {
      final reader = config.creativeLibraryDiscoveryReader;
      if (reader == null) {
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Creative library discovery is not wired.',
          payload: <String, Object?>{
            'error': 'creative_library_discovery_not_wired',
            'toolName': commandType,
          },
        );
      }
      final shortToolName = commandType.startsWith('refusion.')
          ? commandType.substring('refusion.'.length)
          : commandType;
      final payload = reader(
        toolName: shortToolName,
        payload: context.command.payload,
      );
      final isError = payload['error'] is String;
      return RefusionMcpCommandHandlingOutcome(
        summary: isError
            ? 'Creative library discovery returned an issue.'
            : 'Creative library discovery loaded.',
        payload: payload,
      );
    },
  );
}

RefusionMcpCommandHandlingOutcome _defaultMotionMutationHandler({
  required RefusionMcpCommandEnvelope command,
  required String commandType,
  required RefusionMcpMvpToolkitConfig config,
}) {
  if (!_canUseDefaultMotionTools(config)) {
    return RefusionMcpCommandHandlingOutcome(
      summary: 'Command `$commandType` is not wired in this runtime profile.',
      requiresConfirmation: true,
    );
  }
  return config.motionTools.handle(
    command: command,
    project: config.projectReader!.call(),
    rootSceneId: config.rootSceneIdReader!.call(),
    sceneClips: config.sceneClipsReader!.call(),
    channels: config.channelsReader!.call(),
    commitChannels: config.motionChannelsCommit!,
  );
}

RefusionMcpCommandHandlingOutcome _defaultTimelineMutationHandler({
  required RefusionMcpCommandEnvelope command,
  required RefusionMcpMvpToolkitConfig config,
}) {
  if (!_canUseDefaultTimelineTools(config)) {
    return RefusionMcpCommandHandlingOutcome(
      summary:
          'Command `${command.type}` is not wired in this runtime profile.',
      requiresConfirmation: true,
    );
  }
  return config.timelineTools.handle(
    command: command,
    project: config.projectReader!.call(),
    rootSceneId: config.rootSceneIdReader!.call(),
    playheadReader: config.playheadReader!,
    commitProject: config.timelineProjectCommit!,
  );
}

bool _canUseDefaultMotionTools(RefusionMcpMvpToolkitConfig config) {
  return config.projectReader != null &&
      config.rootSceneIdReader != null &&
      config.sceneClipsReader != null &&
      config.channelsReader != null &&
      config.motionChannelsCommit != null;
}

bool _canUseDefaultTimelineTools(RefusionMcpMvpToolkitConfig config) {
  return config.projectReader != null &&
      config.rootSceneIdReader != null &&
      config.playheadReader != null &&
      config.timelineProjectCommit != null;
}

bool _canApplySceneProgram(RefusionMcpMvpToolkitConfig config) {
  return config.projectReader != null &&
      config.rootSceneIdReader != null &&
      config.sceneClipsReader != null &&
      config.channelsReader != null &&
      config.textBindingsReader != null &&
      config.applySceneProgramCommit != null;
}

String? _readSource(Map<String, Object?> payload) {
  final source = payload['source'];
  if (source is String && source.trim().isNotEmpty) {
    return source;
  }
  return null;
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return null;
}

double? _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}
