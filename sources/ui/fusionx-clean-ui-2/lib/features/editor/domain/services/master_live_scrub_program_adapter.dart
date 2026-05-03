import '../models/master_frame_evaluation_models.dart';
import '../models/master_live_scrub_visual_program_models.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_models.dart';

class MasterLiveScrubProgramAdapter {
  const MasterLiveScrubProgramAdapter();

  static const Set<String> _supportedEffectIds = <String>{'gaussianBlur'};

  LiveScrubVisualProgram build({
    required MasterFrameEvaluation frame,
    Map<String, LiveScrubSurfaceSource> sourcesByTargetId =
        const <String, LiveScrubSurfaceSource>{},
    Map<String, LiveScrubTransitionRole> transitionRolesByTargetId =
        const <String, LiveScrubTransitionRole>{},
    Iterable<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
  }) {
    final channelById = <String, MotionPropertyChannelModel>{
      for (final channel in channels) channel.id: channel,
    };
    final grouped = <String, List<MasterEvaluatedPropertyValue>>{};
    for (final value in frame.evaluatedChannels) {
      grouped.putIfAbsent(value.targetId, () => <MasterEvaluatedPropertyValue>[])
          .add(value);
    }
    final targetIds = <String>{
      ...grouped.keys,
      ...sourcesByTargetId.keys,
      ...frame.visibleLayerIds,
    };
    final globalBlockers = <String>[];
    final globalDiagnostics = <String>[...frame.diagnostics];
    final surfaces = <LiveScrubVisualSurface>[];

    for (final targetId in targetIds) {
      final source = sourcesByTargetId[targetId];
      final values = grouped[targetId] ?? const <MasterEvaluatedPropertyValue>[];
      final blockers = <String>[];
      final effects = <LiveScrubEffectBinding>[];
      var transform = const LiveScrubSurfaceTransform();
      var opacity = 1.0;

      for (final value in values) {
        final rendererScalar = value.mapping.renderer.scalar;
        final channel = channelById[value.sourceChannelId];
        final sourceDefinitionId = channel?.definition.id;
        switch (value.propertyDefinitionId) {
          case 'opacity':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_opacity_value:${value.sourceChannelId}');
            } else {
              opacity = rendererScalar.clamp(0.0, 1.0).toDouble();
            }
          case 'position':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_position_value:${value.sourceChannelId}');
              continue;
            }
            if (sourceDefinitionId == MotionPropertyCatalog.positionY.id) {
              transform = transform.copyWith(positionY: rendererScalar);
            } else if (sourceDefinitionId == MotionPropertyCatalog.positionX.id) {
              transform = transform.copyWith(positionX: rendererScalar);
            } else {
              // Fallback for grouped/legacy position channels.
              transform = transform.copyWith(
                positionX: rendererScalar,
                positionY: rendererScalar,
              );
            }
          case 'scale':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_scale_value:${value.sourceChannelId}');
              continue;
            }
            if (sourceDefinitionId == MotionPropertyCatalog.scaleY.id) {
              transform = transform.copyWith(scaleY: rendererScalar);
            } else if (sourceDefinitionId == MotionPropertyCatalog.scaleX.id) {
              transform = transform.copyWith(scaleX: rendererScalar);
            } else {
              // Fallback for grouped/legacy scale channels.
              transform = transform.copyWith(
                scaleX: rendererScalar,
                scaleY: rendererScalar,
              );
            }
          case 'rotation':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_rotation_value:${value.sourceChannelId}');
            } else {
              transform = transform.copyWith(rotationRadians: rendererScalar);
            }
          case 'gaussianBlur':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_effect_value:${value.propertyDefinitionId}');
              continue;
            }
            effects.add(
              LiveScrubEffectBinding(
                id: value.propertyDefinitionId,
                rendererValue: rendererScalar,
                rendererUnit: value.mapping.rendererUnit,
              ),
            );
          default:
            blockers.add(
              'unsupported_property:${value.propertyDefinitionId}:${value.sourceChannelId}',
            );
        }
      }

      final explicitEffectIds = frame.effectParameters.keys;
      for (final effectId in explicitEffectIds) {
        if (_supportedEffectIds.contains(effectId)) {
          final mapping = frame.effectParameters[effectId];
          final rendererScalar = mapping?.renderer.scalar;
          if (mapping != null &&
              rendererScalar != null &&
              rendererScalar.isFinite) {
            effects.add(
              LiveScrubEffectBinding(
                id: effectId,
                rendererValue: rendererScalar,
                rendererUnit: mapping.rendererUnit,
              ),
            );
          } else {
            blockers.add('invalid_effect_value:$effectId');
          }
          continue;
        }
        blockers.add('unsupported_effect:$effectId');
      }

      final sourceKind = source?.kind ?? LiveScrubSourceKind.unknown;
      if (source == null) {
        blockers.add('missing_source_binding:$targetId');
      }

      surfaces.add(
        LiveScrubVisualSurface(
          targetId: targetId,
          sourceKind: sourceKind,
          source: source,
          transitionRole: transitionRolesByTargetId[targetId] ??
              LiveScrubTransitionRole.none,
          transform: transform,
          opacity: opacity,
          effects: effects,
          blockers: blockers,
        ),
      );
      globalBlockers.addAll(blockers);
    }

    final transitionState = LiveScrubTransitionState(
      activeTransitionIds: frame.activeTransitionIds,
      hasRenderableTransitionPixels: false,
      reason: frame.activeTransitionIds.isEmpty
          ? 'no_active_transition'
          : 'phase1_domain_contract_only',
    );
    if (transitionState.hasTransitionWindow) {
      globalDiagnostics.add(
        'transition_window_present_without_pixels:${transitionState.reason}',
      );
    }
    return LiveScrubVisualProgram(
      time: frame.time,
      surfaces: surfaces,
      blockers: globalBlockers,
      diagnostics: globalDiagnostics,
      transitionState: transitionState,
    );
  }
}
