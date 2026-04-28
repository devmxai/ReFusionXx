import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_interpolation_parsing.dart';
import '../models/professional_motion_models.dart';
import '../models/refusion_motion_patch_models.dart';
import 'refusion_motion_patch_import_service.dart';
import 'unified_keyframe_operations.dart';

@immutable
class ReFusionMotionPatchApplyRequest {
  ReFusionMotionPatchApplyRequest({
    required List<MotionPropertyChannelModel> channels,
    required this.importResult,
  }) : channels = List.unmodifiable(channels);

  final List<MotionPropertyChannelModel> channels;
  final ReFusionMotionPatchImportResult importResult;
}

@immutable
class ReFusionMotionPatchApplyResult {
  ReFusionMotionPatchApplyResult({
    required List<MotionPropertyChannelModel> channels,
    List<ReFusionMotionPatchIssue> issues = const <ReFusionMotionPatchIssue>[],
    Set<String> changedKeyframeIds = const <String>{},
  })  : channels = List.unmodifiable(channels),
        issues = List.unmodifiable(issues),
        changedKeyframeIds = Set.unmodifiable(changedKeyframeIds);

  final List<MotionPropertyChannelModel> channels;
  final List<ReFusionMotionPatchIssue> issues;
  final Set<String> changedKeyframeIds;

  bool get hasErrors => issues.any(
        (issue) => issue.severity == ReFusionMotionPatchIssueSeverity.error,
      );

  bool get canApply => !hasErrors;
}

class ReFusionMotionPatchApplicator {
  const ReFusionMotionPatchApplicator({
    UnifiedKeyframeOperations? keyframes,
  }) : keyframes = keyframes ??
            const UnifiedKeyframeOperations(
              channelIdFactory: _channelIdFor,
              keyframeIdFactory: _keyframeIdFor,
            );

  final UnifiedKeyframeOperations keyframes;

  ReFusionMotionPatchApplyResult apply(
    ReFusionMotionPatchApplyRequest request,
  ) {
    final importResult = request.importResult;
    final patch = importResult.patch;
    final issues = <ReFusionMotionPatchIssue>[...importResult.issues];
    if (!importResult.isValid || patch == null) {
      issues.add(
        const ReFusionMotionPatchIssue(
          severity: ReFusionMotionPatchIssueSeverity.error,
          message: 'Cannot apply an invalid motion patch.',
          path: 'motionPatch',
        ),
      );
      return ReFusionMotionPatchApplyResult(
        channels: request.channels,
        issues: issues,
      );
    }

    var channels = request.channels;
    final changedKeyframeIds = <String>{};
    final activeRange = _scopeActiveRange(patch.scopeDurationMs);

    for (final resolved in importResult.resolvedChannels) {
      for (var index = 0;
          index < resolved.operation.keyframes.length;
          index += 1) {
        final patchKeyframe = resolved.operation.keyframes[index];
        final value = _valueFor(
          patchKeyframe.value,
          definition: resolved.definition,
          component: resolved.component,
        );
        final path =
            'operations.${resolved.operation.id}.keyframes[$index].value';
        if (value == null) {
          issues.add(
            ReFusionMotionPatchIssue(
              severity: ReFusionMotionPatchIssueSeverity.error,
              message:
                  'Could not convert value for `${resolved.definition.id}`.',
              path: path,
            ),
          );
          continue;
        }
        final interpolation = _interpolationFor(
          patchKeyframe.easing,
          path: 'operations.${resolved.operation.id}.keyframes[$index].easing',
          issues: issues,
        );
        final applied = keyframes.addKeyframe(
          UnifiedKeyframeAddRequest(
            channels: channels,
            target: resolved.target,
            activeRange: activeRange,
            definition: resolved.definition,
            time: TimelineTime.fromMilliseconds(patchKeyframe.timeMs),
            value: value,
            interpolation: interpolation,
          ),
        );
        channels = applied.channels;
        changedKeyframeIds.addAll(applied.changedKeyframeIds);
        for (final issue in applied.issues) {
          issues.add(_fromUnifiedIssue(issue));
        }
      }
    }

    return ReFusionMotionPatchApplyResult(
      channels: channels,
      issues: issues,
      changedKeyframeIds: changedKeyframeIds,
    );
  }

  TimelineTimeRange _scopeActiveRange(int scopeDurationMs) {
    final safeDurationMs = scopeDurationMs > 0 ? scopeDurationMs : 1;
    final end = TimelineTime.fromMilliseconds(safeDurationMs);
    return TimelineTimeRange(
      start: TimelineTime.zero,
      endExclusive: TimelineTime.fromProjectTicks(end.inProjectTicks + 1),
    );
  }

  MotionPropertyValue? _valueFor(
    Object raw, {
    required MotionPropertyDefinition definition,
    required String? component,
  }) {
    final componentValue = _componentValue(raw, component: component);
    switch (definition.valueKind) {
      case MotionPropertyValueKind.scalar:
        return _scalarValue(componentValue);
      case MotionPropertyValueKind.integer:
        return componentValue is int
            ? MotionPropertyValue.integer(componentValue)
            : null;
      case MotionPropertyValueKind.boolean:
        return componentValue is bool
            ? MotionPropertyValue.boolean(componentValue)
            : null;
      case MotionPropertyValueKind.stringValue:
        return componentValue is String
            ? MotionPropertyValue.stringValue(componentValue)
            : null;
      case MotionPropertyValueKind.enumValue:
        return componentValue is String
            ? MotionPropertyValue.enumValue(componentValue)
            : null;
      case MotionPropertyValueKind.colorArgb:
        return _colorValue(componentValue);
      case MotionPropertyValueKind.point2D:
        return _pointValue(componentValue);
      case MotionPropertyValueKind.size2D:
        return _sizeValue(componentValue);
      case MotionPropertyValueKind.rect:
        return _rectValue(componentValue);
    }
  }

  Object? _componentValue(Object raw, {required String? component}) {
    if (component == null || raw is! Map) {
      return raw;
    }
    return raw[component];
  }

  MotionPropertyValue? _scalarValue(Object? raw) {
    if (raw is num) {
      return MotionPropertyValue.scalar(raw.toDouble());
    }
    if (raw is String) {
      final parsed = double.tryParse(raw.trim());
      if (parsed != null) {
        return MotionPropertyValue.scalar(parsed);
      }
    }
    return null;
  }

  MotionPropertyValue? _colorValue(Object? raw) {
    if (raw is int) {
      return MotionPropertyValue.colorArgb(raw);
    }
    if (raw is String) {
      final normalized = raw.trim().replaceFirst('#', '');
      final parsed = int.tryParse(normalized, radix: 16);
      if (parsed != null) {
        final value = normalized.length <= 6 ? 0xFF000000 | parsed : parsed;
        return MotionPropertyValue.colorArgb(value);
      }
    }
    return null;
  }

  MotionPropertyValue? _pointValue(Object? raw) {
    if (raw is Map && raw['x'] is num && raw['y'] is num) {
      return MotionPropertyValue.point2D(
        MotionPoint2D(
          x: (raw['x'] as num).toDouble(),
          y: (raw['y'] as num).toDouble(),
        ),
      );
    }
    return null;
  }

  MotionPropertyValue? _sizeValue(Object? raw) {
    if (raw is Map && raw['width'] is num && raw['height'] is num) {
      return MotionPropertyValue.size2D(
        MotionSize2D(
          width: (raw['width'] as num).toDouble(),
          height: (raw['height'] as num).toDouble(),
        ),
      );
    }
    return null;
  }

  MotionPropertyValue? _rectValue(Object? raw) {
    if (raw is Map &&
        raw['left'] is num &&
        raw['top'] is num &&
        raw['width'] is num &&
        raw['height'] is num) {
      return MotionPropertyValue.rect(
        MotionRect(
          left: (raw['left'] as num).toDouble(),
          top: (raw['top'] as num).toDouble(),
          width: (raw['width'] as num).toDouble(),
          height: (raw['height'] as num).toDouble(),
        ),
      );
    }
    return null;
  }

  MotionInterpolationSpec _interpolationFor(
    String easing, {
    required String path,
    required List<ReFusionMotionPatchIssue> issues,
  }) {
    final parsed = tryParseNamedMotionInterpolationSpec(easing);
    if (parsed != null) {
      return parsed;
    }
    issues.add(
      ReFusionMotionPatchIssue(
        severity: ReFusionMotionPatchIssueSeverity.warning,
        message: 'Unsupported easing `$easing` was replaced with linear.',
        path: path,
      ),
    );
    return const MotionInterpolationSpec.linear();
  }

  ReFusionMotionPatchIssue _fromUnifiedIssue(UnifiedKeyframeIssue issue) {
    return ReFusionMotionPatchIssue(
      severity: ReFusionMotionPatchIssueSeverity.error,
      message: issue.message,
      path: issue.propertyId,
    );
  }

  static String _channelIdFor({
    required MotionPropertyTarget target,
    required MotionPropertyDefinition definition,
  }) {
    return 'motionPatch.${target.canonicalAddress}.${definition.id}';
  }

  static String _keyframeIdFor({
    required String channelId,
    required TimelineTime time,
  }) {
    return '$channelId.${time.inProjectTicks}';
  }
}
