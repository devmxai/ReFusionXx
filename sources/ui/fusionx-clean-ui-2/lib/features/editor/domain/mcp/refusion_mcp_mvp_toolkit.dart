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
typedef RefusionMcpPreviewCaptureReader = Map<String, Object?> Function(
  int? timeMs,
);
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
      commandType: 'refusion.get_project_state',
      handler: (_) {
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Project state loaded.',
          payload: config.projectStateReader(),
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
