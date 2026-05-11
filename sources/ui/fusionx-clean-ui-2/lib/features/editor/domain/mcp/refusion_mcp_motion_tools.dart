import '../../presentation/models/timeline_time.dart';
import '../models/composition_scene_clip_models.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_interpolation_parsing.dart';
import '../models/professional_motion_models.dart';
import '../models/refusion_motion_patch_models.dart';
import '../services/refusion_motion_patch_applicator.dart';
import '../services/refusion_motion_patch_import_service.dart';
import '../services/scene_mention_index.dart';
import '../services/unified_keyframe_operations.dart';
import 'refusion_mcp_command.dart';
import 'refusion_mcp_command_bus.dart';
import 'refusion_mcp_transaction.dart';

class RefusionMcpMotionChannelsCommitRequest {
  const RefusionMcpMotionChannelsCommitRequest({
    required this.command,
    required this.channels,
    this.summary,
    this.diagnostics = const <String>[],
    this.changedKeyframeIds = const <String>{},
  });

  final RefusionMcpCommandEnvelope command;
  final List<MotionPropertyChannelModel> channels;
  final String? summary;
  final List<String> diagnostics;
  final Set<String> changedKeyframeIds;
}

class RefusionMcpMotionChannelsCommitResult {
  const RefusionMcpMotionChannelsCommitResult({
    required this.revisionAfter,
    this.summary,
    this.diagnostics = const <String>[],
  });

  final int revisionAfter;
  final String? summary;
  final List<String> diagnostics;
}

typedef RefusionMcpMotionChannelsCommit = RefusionMcpMotionChannelsCommitResult
    Function(RefusionMcpMotionChannelsCommitRequest request);

class RefusionMcpMotionTools {
  const RefusionMcpMotionTools({
    ReFusionMotionPatchImportService importService =
        const ReFusionMotionPatchImportService(),
    ReFusionMotionPatchApplicator patchApplicator =
        const ReFusionMotionPatchApplicator(),
    UnifiedKeyframeOperations keyframes = const UnifiedKeyframeOperations(),
    SceneMentionIndex mentionIndex = const SceneMentionIndex(),
  })  : _importService = importService,
        _patchApplicator = patchApplicator,
        _keyframes = keyframes,
        _mentionIndex = mentionIndex;

  final ReFusionMotionPatchImportService _importService;
  final ReFusionMotionPatchApplicator _patchApplicator;
  final UnifiedKeyframeOperations _keyframes;
  final SceneMentionIndex _mentionIndex;

  RefusionMcpCommandHandlingOutcome handle({
    required RefusionMcpCommandEnvelope command,
    required MotionProjectModel project,
    required String rootSceneId,
    required List<CompositionSceneClipModel> sceneClips,
    required List<MotionPropertyChannelModel> channels,
    required RefusionMcpMotionChannelsCommit commitChannels,
  }) {
    switch (command.type) {
      case 'refusion.apply_motion_patch':
        return _applyMotionPatch(
          command: command,
          project: project,
          rootSceneId: rootSceneId,
          sceneClips: sceneClips,
          channels: channels,
          commitChannels: commitChannels,
        );
      case 'refusion.keyframe_edit':
        return _keyframeEdit(
          command: command,
          project: project,
          rootSceneId: rootSceneId,
          channels: channels,
          commitChannels: commitChannels,
        );
      case 'refusion.set_element_transform':
        return _setElementTransform(
          command: command,
          project: project,
          rootSceneId: rootSceneId,
          channels: channels,
          commitChannels: commitChannels,
        );
      default:
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Unsupported motion command `${command.type}`.',
          requiresConfirmation: true,
        );
    }
  }

  RefusionMcpCommandHandlingOutcome _applyMotionPatch({
    required RefusionMcpCommandEnvelope command,
    required MotionProjectModel project,
    required String rootSceneId,
    required List<CompositionSceneClipModel> sceneClips,
    required List<MotionPropertyChannelModel> channels,
    required RefusionMcpMotionChannelsCommit commitChannels,
  }) {
    final source = _sourceFrom(command.payload);
    if (source == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Motion patch source is missing.',
        requiresConfirmation: true,
      );
    }
    final mentionIndex = _mentionIndex.buildForScene(
      project: project,
      sceneId: rootSceneId,
      sceneClips: sceneClips,
    );
    final importResult = _importService.validate(
      source: source,
      mentionEntities: mentionIndex.entities,
      scopeDurationMs: _readInt(command.payload['scopeDurationMs']) ?? 10000,
      fileName: command.payload['fileName'] as String?,
    );
    final applyResult = _patchApplicator.apply(
      ReFusionMotionPatchApplyRequest(
        channels: channels,
        importResult: importResult,
      ),
    );
    final diagnostics = <String>[
      ...importResult.issues.map(_patchIssueToMessage),
      ...applyResult.issues.map(_patchIssueToMessage),
    ];
    if (applyResult.hasErrors) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Motion patch validation/apply returned errors.',
        diagnostics: diagnostics,
        payload: <String, Object?>{
          'isValid': false,
          'issueCount': applyResult.issues.length,
        },
      );
    }
    return RefusionMcpCommandHandlingOutcome(
      summary: 'Motion patch is ready to commit.',
      diagnostics: diagnostics,
      patchPreview: RefusionMcpPatchPreview(
        affectedObjects: importResult.resolvedChannels
            .map((resolved) => resolved.target.targetId)
            .toSet()
            .toList(growable: false),
        changedProperties: importResult.resolvedChannels
            .map((resolved) => resolved.definition.id)
            .toSet()
            .toList(growable: false),
      ),
      payload: <String, Object?>{
        'isValid': true,
        'issueCount': applyResult.issues.length,
        'changedKeyframeCount': applyResult.changedKeyframeIds.length,
      },
      commitOperation: () {
        final commit = commitChannels(
          RefusionMcpMotionChannelsCommitRequest(
            command: command,
            channels: applyResult.channels,
            summary: 'Apply motion patch',
            diagnostics: diagnostics,
            changedKeyframeIds: applyResult.changedKeyframeIds,
          ),
        );
        return RefusionMcpCommitExecution(
          revisionAfter: commit.revisionAfter,
          summary: commit.summary,
          undo: () {
            final undoCommit = commitChannels(
              RefusionMcpMotionChannelsCommitRequest(
                command: command,
                channels: channels,
                summary: 'Undo ${commit.summary ?? 'Apply motion patch'}',
              ),
            );
            return undoCommit.revisionAfter;
          },
          redo: () {
            final redoCommit = commitChannels(
              RefusionMcpMotionChannelsCommitRequest(
                command: command,
                channels: applyResult.channels,
                summary: 'Redo ${commit.summary ?? 'Apply motion patch'}',
              ),
            );
            return redoCommit.revisionAfter;
          },
        );
      },
    );
  }

  RefusionMcpCommandHandlingOutcome _keyframeEdit({
    required RefusionMcpCommandEnvelope command,
    required MotionProjectModel project,
    required String rootSceneId,
    required List<MotionPropertyChannelModel> channels,
    required RefusionMcpMotionChannelsCommit commitChannels,
  }) {
    final action =
        (command.payload['action'] as String?)?.trim().toLowerCase() ?? 'add';
    switch (action) {
      case 'add':
        return _addKeyframe(
          command: command,
          project: project,
          rootSceneId: rootSceneId,
          channels: channels,
          commitChannels: commitChannels,
        );
      case 'set':
        return _setKeyframeValue(
          command: command,
          channels: channels,
          commitChannels: commitChannels,
        );
      case 'move':
        return _moveKeyframe(
          command: command,
          channels: channels,
          commitChannels: commitChannels,
        );
      case 'delete':
        return _deleteKeyframe(
          command: command,
          channels: channels,
          commitChannels: commitChannels,
        );
      case 'ease':
        return _easyEaseKeyframes(
          command: command,
          channels: channels,
          commitChannels: commitChannels,
        );
      default:
        return RefusionMcpCommandHandlingOutcome(
          summary: 'Unsupported keyframe action `$action`.',
          requiresConfirmation: true,
        );
    }
  }

  RefusionMcpCommandHandlingOutcome _setElementTransform({
    required RefusionMcpCommandEnvelope command,
    required MotionProjectModel project,
    required String rootSceneId,
    required List<MotionPropertyChannelModel> channels,
    required RefusionMcpMotionChannelsCommit commitChannels,
  }) {
    final target = _resolveElementTarget(
      project: project,
      rootSceneId: rootSceneId,
      targetId: command.payload['targetId'] as String?,
    );
    if (target == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Transform target element is missing or unknown.',
        requiresConfirmation: true,
      );
    }
    final keyframeTime = _readInt(command.payload['timeMs']);
    var nextChannels = channels;
    final changed = <String>{};
    final issues = <String>[];

    void applyScalar({
      required MotionPropertyDefinition definition,
      required double? value,
    }) {
      if (value == null) {
        return;
      }
      if (keyframeTime != null) {
        final result = _keyframes.addKeyframe(
          UnifiedKeyframeAddRequest(
            channels: nextChannels,
            target: target,
            activeRange: _sceneRangeFor(project, rootSceneId),
            definition: definition,
            time: TimelineTime.fromMilliseconds(keyframeTime),
            value: MotionPropertyValue.scalar(value),
            interpolation: const MotionInterpolationSpec.linear(),
          ),
        );
        nextChannels = result.channels;
        changed.addAll(result.changedKeyframeIds);
        issues.addAll(result.issues.map((issue) => issue.message));
      } else {
        nextChannels = _upsertBaseValue(
          channels: nextChannels,
          target: target,
          definition: definition,
          value: MotionPropertyValue.scalar(value),
        );
      }
    }

    final transform = _readMap(command.payload['transform']);
    final position = _readMap(transform['position']);
    final scale = _readMap(transform['scale']);
    applyScalar(
      definition: MotionPropertyCatalog.positionX,
      value: _readDouble(position['x']) ?? _readDouble(command.payload['x']),
    );
    applyScalar(
      definition: MotionPropertyCatalog.positionY,
      value: _readDouble(position['y']) ?? _readDouble(command.payload['y']),
    );
    applyScalar(
      definition: MotionPropertyCatalog.scaleX,
      value: _readDouble(scale['x']) ?? _readDouble(command.payload['scaleX']),
    );
    applyScalar(
      definition: MotionPropertyCatalog.scaleY,
      value: _readDouble(scale['y']) ?? _readDouble(command.payload['scaleY']),
    );
    applyScalar(
      definition: MotionPropertyCatalog.rotationDegrees,
      value: _readDouble(transform['rotationDegrees']) ??
          _readDouble(command.payload['rotationDegrees']),
    );
    applyScalar(
      definition: MotionPropertyCatalog.opacity,
      value: _readDouble(transform['opacity']) ??
          _readDouble(command.payload['opacity']),
    );

    return RefusionMcpCommandHandlingOutcome(
      summary: keyframeTime == null
          ? 'Transform values are ready to commit.'
          : 'Transform keyframes are ready to commit.',
      diagnostics: issues,
      patchPreview: RefusionMcpPatchPreview(
        affectedObjects: <String>[target.targetId],
        changedProperties: <String>[
          MotionPropertyCatalog.positionX.id,
          MotionPropertyCatalog.positionY.id,
          MotionPropertyCatalog.scaleX.id,
          MotionPropertyCatalog.scaleY.id,
          MotionPropertyCatalog.rotationDegrees.id,
          MotionPropertyCatalog.opacity.id,
        ],
      ),
      commitOperation: () {
        final commit = commitChannels(
          RefusionMcpMotionChannelsCommitRequest(
            command: command,
            channels: nextChannels,
            summary: 'Set element transform',
            diagnostics: issues,
            changedKeyframeIds: changed,
          ),
        );
        return RefusionMcpCommitExecution(
          revisionAfter: commit.revisionAfter,
          summary: commit.summary,
          undo: () {
            final undoCommit = commitChannels(
              RefusionMcpMotionChannelsCommitRequest(
                command: command,
                channels: channels,
                summary: 'Undo ${commit.summary ?? 'Set element transform'}',
              ),
            );
            return undoCommit.revisionAfter;
          },
          redo: () {
            final redoCommit = commitChannels(
              RefusionMcpMotionChannelsCommitRequest(
                command: command,
                channels: nextChannels,
                summary: 'Redo ${commit.summary ?? 'Set element transform'}',
              ),
            );
            return redoCommit.revisionAfter;
          },
        );
      },
      payload: <String, Object?>{
        'changedKeyframeCount': changed.length,
        'mode': keyframeTime == null ? 'static' : 'keyframe',
      },
    );
  }

  RefusionMcpCommandHandlingOutcome _addKeyframe({
    required RefusionMcpCommandEnvelope command,
    required MotionProjectModel project,
    required String rootSceneId,
    required List<MotionPropertyChannelModel> channels,
    required RefusionMcpMotionChannelsCommit commitChannels,
  }) {
    final target = _resolveElementTarget(
      project: project,
      rootSceneId: rootSceneId,
      targetId: command.payload['targetId'] as String?,
    );
    if (target == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Missing keyframe target element.',
        requiresConfirmation: true,
      );
    }
    final definition = _resolveDefinition(command.payload['property']);
    if (definition == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Unsupported keyframe property.',
        requiresConfirmation: true,
      );
    }
    final timeMs = _readInt(command.payload['timeMs']);
    final value = _valueFor(
      definition: definition,
      raw: command.payload['value'],
    );
    if (timeMs == null || value == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Keyframe add requires valid `timeMs` and `value`.',
        requiresConfirmation: true,
      );
    }
    final easing = command.payload['easing'] as String?;
    final interpolation = easing == null
        ? const MotionInterpolationSpec.linear()
        : _parseEasing(easing);
    final result = _keyframes.addKeyframe(
      UnifiedKeyframeAddRequest(
        channels: channels,
        target: target,
        activeRange: _sceneRangeFor(project, rootSceneId),
        definition: definition,
        time: TimelineTime.fromMilliseconds(timeMs),
        value: value,
        interpolation: interpolation,
      ),
    );
    return _commitKeyframeResult(
      command: command,
      summary: 'Keyframe add is ready to commit.',
      previousChannels: channels,
      result: result,
      commitChannels: commitChannels,
    );
  }

  RefusionMcpCommandHandlingOutcome _setKeyframeValue({
    required RefusionMcpCommandEnvelope command,
    required List<MotionPropertyChannelModel> channels,
    required RefusionMcpMotionChannelsCommit commitChannels,
  }) {
    final channelId = command.payload['channelId'] as String?;
    final keyframeId = command.payload['keyframeId'] as String?;
    if (channelId == null || keyframeId == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Keyframe set requires channelId and keyframeId.',
        requiresConfirmation: true,
      );
    }
    final channel = channels
        .where((entry) => entry.id == channelId)
        .cast<MotionPropertyChannelModel?>()
        .firstOrNull;
    if (channel == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Channel `$channelId` was not found.',
        requiresConfirmation: true,
      );
    }
    final value = _valueFor(
      definition: channel.definition,
      raw: command.payload['value'],
    );
    if (value == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Invalid keyframe value for `${channel.definition.id}`.',
        requiresConfirmation: true,
      );
    }
    final result = _keyframes.setKeyframeValue(
      UnifiedKeyframeValueRequest(
        channels: channels,
        channelId: channelId,
        keyframeId: keyframeId,
        value: value,
      ),
    );
    return _commitKeyframeResult(
      command: command,
      summary: 'Keyframe value edit is ready to commit.',
      previousChannels: channels,
      result: result,
      commitChannels: commitChannels,
    );
  }

  RefusionMcpCommandHandlingOutcome _moveKeyframe({
    required RefusionMcpCommandEnvelope command,
    required List<MotionPropertyChannelModel> channels,
    required RefusionMcpMotionChannelsCommit commitChannels,
  }) {
    final channelId = command.payload['channelId'] as String?;
    final keyframeId = command.payload['keyframeId'] as String?;
    final timeMs = _readInt(command.payload['timeMs']);
    if (channelId == null || keyframeId == null || timeMs == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Keyframe move requires channelId, keyframeId, and timeMs.',
        requiresConfirmation: true,
      );
    }
    final result = _keyframes.moveKeyframe(
      UnifiedKeyframeMoveRequest(
        channels: channels,
        channelId: channelId,
        keyframeId: keyframeId,
        time: TimelineTime.fromMilliseconds(timeMs),
      ),
    );
    return _commitKeyframeResult(
      command: command,
      summary: 'Keyframe move is ready to commit.',
      previousChannels: channels,
      result: result,
      commitChannels: commitChannels,
    );
  }

  RefusionMcpCommandHandlingOutcome _deleteKeyframe({
    required RefusionMcpCommandEnvelope command,
    required List<MotionPropertyChannelModel> channels,
    required RefusionMcpMotionChannelsCommit commitChannels,
  }) {
    final channelId = command.payload['channelId'] as String?;
    final keyframeId = command.payload['keyframeId'] as String?;
    if (channelId == null || keyframeId == null) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Keyframe delete requires channelId and keyframeId.',
        requiresConfirmation: true,
      );
    }
    final result = _keyframes.deleteKeyframe(
      UnifiedKeyframeDeleteRequest(
        channels: channels,
        channelId: channelId,
        keyframeId: keyframeId,
      ),
    );
    return _commitKeyframeResult(
      command: command,
      summary: 'Keyframe delete is ready to commit.',
      previousChannels: channels,
      result: result,
      commitChannels: commitChannels,
    );
  }

  RefusionMcpCommandHandlingOutcome _easyEaseKeyframes({
    required RefusionMcpCommandEnvelope command,
    required List<MotionPropertyChannelModel> channels,
    required RefusionMcpMotionChannelsCommit commitChannels,
  }) {
    final keyframeIds = (command.payload['keyframeIds'] as List?)
            ?.whereType<String>()
            .toSet() ??
        const <String>{};
    if (keyframeIds.isEmpty) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Keyframe ease requires keyframeIds.',
        requiresConfirmation: true,
      );
    }
    final modeRaw = (command.payload['mode'] as String?)?.trim().toLowerCase();
    final mode = switch (modeRaw) {
      'easein' || 'ease_in' || 'in' => UnifiedEasyEaseMode.easyEaseIn,
      'easeout' || 'ease_out' || 'out' => UnifiedEasyEaseMode.easyEaseOut,
      'remove' || 'none' => UnifiedEasyEaseMode.removeEase,
      _ => UnifiedEasyEaseMode.easyEase,
    };
    final result = _keyframes.applyEasyEase(
      UnifiedKeyframeEasyEaseRequest(
        channels: channels,
        keyframeIds: keyframeIds,
        mode: mode,
      ),
    );
    return _commitKeyframeResult(
      command: command,
      summary: 'Keyframe easing update is ready to commit.',
      previousChannels: channels,
      result: result,
      commitChannels: commitChannels,
    );
  }

  RefusionMcpCommandHandlingOutcome _commitKeyframeResult({
    required RefusionMcpCommandEnvelope command,
    required String summary,
    required List<MotionPropertyChannelModel> previousChannels,
    required UnifiedKeyframeOperationResult result,
    required RefusionMcpMotionChannelsCommit commitChannels,
  }) {
    final diagnostics =
        result.issues.map((issue) => issue.message).toList(growable: false);
    final hasError = result.issues.isNotEmpty;
    if (hasError) {
      return RefusionMcpCommandHandlingOutcome(
        summary: 'Keyframe operation returned issues.',
        diagnostics: diagnostics,
        payload: <String, Object?>{
          'isValid': false,
          'issueCount': result.issues.length,
        },
      );
    }
    return RefusionMcpCommandHandlingOutcome(
      summary: summary,
      diagnostics: diagnostics,
      payload: <String, Object?>{
        'isValid': true,
        'changedKeyframeCount': result.changedKeyframeIds.length,
      },
      commitOperation: () {
        final commit = commitChannels(
          RefusionMcpMotionChannelsCommitRequest(
            command: command,
            channels: result.channels,
            summary: summary,
            diagnostics: diagnostics,
            changedKeyframeIds: result.changedKeyframeIds,
          ),
        );
        return RefusionMcpCommitExecution(
          revisionAfter: commit.revisionAfter,
          summary: commit.summary,
          undo: () {
            final undoCommit = commitChannels(
              RefusionMcpMotionChannelsCommitRequest(
                command: command,
                channels: previousChannels,
                summary: 'Undo ${commit.summary ?? summary}',
              ),
            );
            return undoCommit.revisionAfter;
          },
          redo: () {
            final redoCommit = commitChannels(
              RefusionMcpMotionChannelsCommitRequest(
                command: command,
                channels: result.channels,
                summary: 'Redo ${commit.summary ?? summary}',
              ),
            );
            return redoCommit.revisionAfter;
          },
        );
      },
    );
  }

  MotionPropertyTarget? _resolveElementTarget({
    required MotionProjectModel project,
    required String rootSceneId,
    required String? targetId,
  }) {
    if (targetId == null || targetId.trim().isEmpty) {
      return null;
    }
    final scene = project.scenes
        .where((entry) => entry.id == rootSceneId)
        .cast<MotionSceneModel?>()
        .firstOrNull;
    if (scene == null) {
      return null;
    }
    for (final layer in scene.layers) {
      for (final element in layer.elements) {
        if (element.id == targetId) {
          return MotionPropertyTarget(
            kind: MotionTargetKind.element,
            targetId: element.id,
            projectId: project.id,
            sceneId: scene.id,
            layerId: layer.id,
            elementId: element.id,
          );
        }
      }
    }
    return null;
  }

  TimelineTimeRange _sceneRangeFor(
    MotionProjectModel project,
    String rootSceneId,
  ) {
    final scene = project.scenes
        .where((entry) => entry.id == rootSceneId)
        .cast<MotionSceneModel?>()
        .firstOrNull;
    return scene?.projectRange ??
        TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: TimelineTime.fromMilliseconds(20000),
        );
  }

  MotionPropertyDefinition? _resolveDefinition(Object? rawProperty) {
    if (rawProperty is! String || rawProperty.trim().isEmpty) {
      return null;
    }
    final normalized = rawProperty.trim().toLowerCase();
    return _propertyByAlias[normalized];
  }

  MotionPropertyValue? _valueFor({
    required MotionPropertyDefinition definition,
    required Object? raw,
  }) {
    switch (definition.valueKind) {
      case MotionPropertyValueKind.scalar:
        final scalar = _readDouble(raw);
        if (scalar == null) {
          return null;
        }
        return MotionPropertyValue.scalar(scalar);
      case MotionPropertyValueKind.integer:
        final value = _readInt(raw);
        if (value == null) {
          return null;
        }
        return MotionPropertyValue.integer(value);
      case MotionPropertyValueKind.boolean:
        if (raw is bool) {
          return MotionPropertyValue.boolean(raw);
        }
        return null;
      case MotionPropertyValueKind.stringValue:
        if (raw is String) {
          return MotionPropertyValue.stringValue(raw);
        }
        return null;
      case MotionPropertyValueKind.enumValue:
        if (raw is String) {
          return MotionPropertyValue.enumValue(raw);
        }
        return null;
      case MotionPropertyValueKind.colorArgb:
        if (raw is int) {
          return MotionPropertyValue.colorArgb(raw);
        }
        return null;
      case MotionPropertyValueKind.point2D:
        final value = _readMap(raw);
        final x = _readDouble(value['x']);
        final y = _readDouble(value['y']);
        if (x == null || y == null) {
          return null;
        }
        return MotionPropertyValue.point2D(MotionPoint2D(x: x, y: y));
      case MotionPropertyValueKind.size2D:
        final value = _readMap(raw);
        final width = _readDouble(value['width']);
        final height = _readDouble(value['height']);
        if (width == null || height == null) {
          return null;
        }
        return MotionPropertyValue.size2D(
          MotionSize2D(width: width, height: height),
        );
      case MotionPropertyValueKind.rect:
        final value = _readMap(raw);
        final left = _readDouble(value['left']);
        final top = _readDouble(value['top']);
        final width = _readDouble(value['width']);
        final height = _readDouble(value['height']);
        if (left == null || top == null || width == null || height == null) {
          return null;
        }
        return MotionPropertyValue.rect(
          MotionRect(
            left: left,
            top: top,
            width: width,
            height: height,
          ),
        );
    }
  }

  MotionInterpolationSpec _parseEasing(String easing) {
    final parsed = tryParseNamedMotionInterpolationSpec(easing);
    return parsed ?? const MotionInterpolationSpec.linear();
  }

  List<MotionPropertyChannelModel> _upsertBaseValue({
    required List<MotionPropertyChannelModel> channels,
    required MotionPropertyTarget target,
    required MotionPropertyDefinition definition,
    required MotionPropertyValue value,
  }) {
    final index = channels.indexWhere(
      (channel) =>
          channel.target.canonicalAddress == target.canonicalAddress &&
          channel.definition.id == definition.id,
    );
    if (index < 0) {
      return <MotionPropertyChannelModel>[
        ...channels,
        MotionPropertyChannelModel(
          id: _defaultChannelIdFor(target: target, definition: definition),
          target: target,
          definition: definition,
          baseValue: value,
        ),
      ];
    }
    return <MotionPropertyChannelModel>[
      for (var i = 0; i < channels.length; i += 1)
        if (i == index) channels[i].copyWith(baseValue: value) else channels[i],
    ];
  }

  String? _sourceFrom(Map<String, Object?> payload) {
    final source = payload['source'];
    if (source is String && source.trim().isNotEmpty) {
      return source;
    }
    return null;
  }

  String _patchIssueToMessage(ReFusionMotionPatchIssue issue) {
    final path = issue.path;
    if (path == null || path.trim().isEmpty) {
      return '${issue.severity.name}: ${issue.message}';
    }
    return '${issue.severity.name}: ${issue.message} [$path]';
  }

  Map<String, Object?> _readMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      final casted = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is String) {
          casted[entry.key as String] = entry.value;
        }
      }
      return casted;
    }
    return const <String, Object?>{};
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static String _defaultChannelIdFor({
    required MotionPropertyTarget target,
    required MotionPropertyDefinition definition,
  }) {
    return 'unifiedKeyframe.${target.canonicalAddress}.${definition.id}';
  }

  static final Map<String, MotionPropertyDefinition> _propertyByAlias =
      <String, MotionPropertyDefinition>{
    MotionPropertyCatalog.positionX.id.toLowerCase():
        MotionPropertyCatalog.positionX,
    'position.x': MotionPropertyCatalog.positionX,
    'transform.position.x': MotionPropertyCatalog.positionX,
    MotionPropertyCatalog.positionY.id.toLowerCase():
        MotionPropertyCatalog.positionY,
    'position.y': MotionPropertyCatalog.positionY,
    'transform.position.y': MotionPropertyCatalog.positionY,
    MotionPropertyCatalog.scaleX.id.toLowerCase(): MotionPropertyCatalog.scaleX,
    'scale.x': MotionPropertyCatalog.scaleX,
    'transform.scale.x': MotionPropertyCatalog.scaleX,
    MotionPropertyCatalog.scaleY.id.toLowerCase(): MotionPropertyCatalog.scaleY,
    'scale.y': MotionPropertyCatalog.scaleY,
    'transform.scale.y': MotionPropertyCatalog.scaleY,
    MotionPropertyCatalog.rotationDegrees.id.toLowerCase():
        MotionPropertyCatalog.rotationDegrees,
    'rotation': MotionPropertyCatalog.rotationDegrees,
    'rotation.degrees': MotionPropertyCatalog.rotationDegrees,
    MotionPropertyCatalog.opacity.id.toLowerCase():
        MotionPropertyCatalog.opacity,
    'opacity': MotionPropertyCatalog.opacity,
  };
}
