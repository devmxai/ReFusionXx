import '../models/master_frame_evaluation_models.dart';
import '../models/master_visual_program_models.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_models.dart';

class MasterVisualProgramAdapter {
  const MasterVisualProgramAdapter();

  static const Set<String> _supportedEffectIds = <String>{
    'gaussianBlur',
    'blurHorizontal',
    'blurVertical',
    'blurMix',
    'blurEdgeMode',
    'blurCrop',
    'shadowOpacity',
    'shadowBlur',
    'shadowOffsetX',
    'shadowOffsetY',
    'shadowSpread',
    'trimStart',
    'trimEnd',
    'trimOffset',
    'motionBlurAmount',
    'tileOutputScale',
  };

  static const Set<String> _edgeFillPropertyIds = <String>{
    'edgeFillEnabled',
    'edgeFillAmount',
    'edgeFillMode',
    'edgeFillOverscanScale',
    'edgeFillSoftnessPx',
    'edgeFillBlurSigmaPx',
    'edgeFillMaxExpansionPx',
    'edgeFillAffectRotation',
    'edgeFillAffectScale',
    'edgeFillAffectPosition',
    'edgeFillAffectMotionBlur',
  };

  static const Set<String> _motionBlurPropertyIds = <String>{
    'motionBlurEnabled',
    'motionBlurAmount',
    'motionBlurShutterAngle',
    'motionBlurShutterPhase',
    'motionBlurSamples',
    'motionBlurAdaptiveSampleLimit',
    'motionBlurMaxTrailPx',
    'motionBlurAffectPosition',
    'motionBlurAffectScale',
    'motionBlurAffectRotation',
  };

  MasterVisualProgram build({
    required MasterFrameEvaluation frame,
    Map<String, MasterVisualSourceBinding> sourcesByTargetId =
        const <String, MasterVisualSourceBinding>{},
    Map<String, MasterVisualTransitionRole> transitionRolesByTargetId =
        const <String, MasterVisualTransitionRole>{},
    Iterable<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
  }) {
    final channelById = <String, MotionPropertyChannelModel>{
      for (final channel in channels) channel.id: channel,
    };
    final grouped = <String, List<MasterEvaluatedPropertyValue>>{};
    for (final value in frame.evaluatedChannels) {
      grouped
          .putIfAbsent(value.targetId, () => <MasterEvaluatedPropertyValue>[])
          .add(value);
    }
    final targetIds = <String>{
      ...grouped.keys,
      ...sourcesByTargetId.keys,
      ...frame.visibleLayerIds,
    };
    final orderedTargetIds = _orderedTargetIds(
      targetIds: targetIds,
      visibleLayerIds: frame.visibleLayerIds,
    );
    final drawOrderByTargetId = <String, int>{
      for (var index = 0; index < orderedTargetIds.length; index++)
        orderedTargetIds[index]: index,
    };
    final globalBlockers = <String>[];
    final globalDiagnostics = <String>[...frame.diagnostics];
    final surfaces = <MasterVisualSurface>[];

    for (final targetId in orderedTargetIds) {
      final source = sourcesByTargetId[targetId];
      final values =
          grouped[targetId] ?? const <MasterEvaluatedPropertyValue>[];
      final blockers = <String>[];
      final effectsById = <String, MasterVisualEffectBinding>{};
      var transform = const MasterVisualTransform();
      var crop = const MasterVisualCrop();
      var mask = const MasterVisualMask();
      var colors = const MasterVisualColorStyle();
      var textStyle = const MasterVisualTextStyle();
      var shapeStyle = const MasterVisualShapeStyle();
      var opacity = 1.0;
      var motionBlur = const MasterMotionBlurPolicy();
      var motionBlurEnabledWasAuthored = false;
      var edgeFill = const MasterEdgeFillPolicy();
      var edgeFillEnabledWasAuthored = false;

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
            } else if (sourceDefinitionId ==
                MotionPropertyCatalog.positionX.id) {
              transform = transform.copyWith(positionX: rendererScalar);
            } else {
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
          case 'cropRect':
            final rect = value.mapping.renderer.rect;
            if (rect == null) {
              blockers.add('invalid_crop_value:${value.sourceChannelId}');
            } else {
              crop = crop.copyWith(rect: rect);
            }
          case 'maskRevealProgress':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_mask_value:${value.sourceChannelId}');
            } else {
              mask = mask.copyWith(
                revealProgress: rendererScalar.clamp(0.0, 1.0).toDouble(),
              );
            }
          case 'shadowColor':
            final colorArgb = value.mapping.renderer.colorArgb;
            if (colorArgb == null) {
              blockers.add('invalid_color_value:${value.sourceChannelId}');
            } else {
              colors = colors.copyWith(shadowColorArgb: colorArgb);
            }
          case 'visualColor':
            final colorArgb = value.mapping.renderer.colorArgb;
            if (colorArgb == null) {
              blockers.add('invalid_color_value:${value.sourceChannelId}');
            } else {
              colors = colors.copyWith(visualColorArgb: colorArgb);
            }
          case 'shapeWidth':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_shape_value:${value.sourceChannelId}');
            } else {
              shapeStyle = shapeStyle.copyWith(width: rendererScalar);
            }
          case 'shapeHeight':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_shape_value:${value.sourceChannelId}');
            } else {
              shapeStyle = shapeStyle.copyWith(height: rendererScalar);
            }
          case 'shapeCornerRadius':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_shape_value:${value.sourceChannelId}');
            } else {
              shapeStyle = shapeStyle.copyWith(cornerRadius: rendererScalar);
            }
          case 'trimStart':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_shape_value:${value.sourceChannelId}');
            } else {
              shapeStyle = shapeStyle.copyWith(trimStart: rendererScalar);
            }
          case 'trimEnd':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_shape_value:${value.sourceChannelId}');
            } else {
              shapeStyle = shapeStyle.copyWith(trimEnd: rendererScalar);
            }
          case 'trimOffset':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_shape_value:${value.sourceChannelId}');
            } else {
              shapeStyle = shapeStyle.copyWith(trimOffset: rendererScalar);
            }
          case 'textFontSize':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_text_value:${value.sourceChannelId}');
            } else {
              textStyle = textStyle.copyWith(fontSize: rendererScalar);
            }
          case 'textFontWeight':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_text_value:${value.sourceChannelId}');
            } else {
              textStyle = textStyle.copyWith(fontWeight: rendererScalar);
            }
          case 'textFontFamily':
            textStyle = textStyle.copyWith(
              fontFamily: value.mapping.renderer.token,
            );
          case 'textFontStyle':
            textStyle = textStyle.copyWith(
              fontStyle: value.mapping.renderer.token,
            );
          case 'textLineHeight':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_text_value:${value.sourceChannelId}');
            } else {
              textStyle = textStyle.copyWith(lineHeight: rendererScalar);
            }
          case 'textAlignment':
            textStyle = textStyle.copyWith(
              alignment: value.mapping.renderer.token,
            );
          case 'textLetterSpacing':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_text_value:${value.sourceChannelId}');
            } else {
              textStyle = textStyle.copyWith(letterSpacing: rendererScalar);
            }
          case 'textRevealProgress':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_text_value:${value.sourceChannelId}');
            } else {
              textStyle = textStyle.copyWith(revealProgress: rendererScalar);
            }
          case 'motionBlurAmount':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers.add('invalid_effect_value:motionBlurAmount');
              continue;
            }
            motionBlur = _applyMotionBlurScalar(
              motionBlur,
              propertyId: value.propertyDefinitionId,
              rendererScalar: rendererScalar,
              enabledWasAuthored: motionBlurEnabledWasAuthored,
            );
          case 'motionBlurShutterAngle':
          case 'motionBlurShutterPhase':
          case 'motionBlurSamples':
          case 'motionBlurAdaptiveSampleLimit':
          case 'motionBlurMaxTrailPx':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers
                  .add('invalid_effect_value:${value.propertyDefinitionId}');
              continue;
            }
            motionBlur = _applyMotionBlurScalar(
              motionBlur,
              propertyId: value.propertyDefinitionId,
              rendererScalar: rendererScalar,
              enabledWasAuthored: motionBlurEnabledWasAuthored,
            );
          case 'motionBlurEnabled':
          case 'motionBlurAffectPosition':
          case 'motionBlurAffectScale':
          case 'motionBlurAffectRotation':
            final rendererBool = value.mapping.renderer.booleanValue;
            if (rendererBool == null) {
              blockers
                  .add('invalid_effect_value:${value.propertyDefinitionId}');
              continue;
            }
            if (value.propertyDefinitionId == 'motionBlurEnabled') {
              motionBlurEnabledWasAuthored = true;
            }
            motionBlur = _applyMotionBlurBoolean(
              motionBlur,
              propertyId: value.propertyDefinitionId,
              rendererBool: rendererBool,
            );
          case 'edgeFillEnabled':
          case 'edgeFillAffectRotation':
          case 'edgeFillAffectScale':
          case 'edgeFillAffectPosition':
          case 'edgeFillAffectMotionBlur':
            final rendererBool = value.mapping.renderer.booleanValue;
            if (rendererBool == null) {
              blockers
                  .add('invalid_effect_value:${value.propertyDefinitionId}');
              continue;
            }
            if (value.propertyDefinitionId == 'edgeFillEnabled') {
              edgeFillEnabledWasAuthored = true;
            }
            edgeFill = _applyEdgeFillBoolean(
              edgeFill,
              propertyId: value.propertyDefinitionId,
              rendererBool: rendererBool,
            );
          case 'edgeFillAmount':
          case 'edgeFillMode':
          case 'edgeFillOverscanScale':
          case 'edgeFillSoftnessPx':
          case 'edgeFillBlurSigmaPx':
          case 'edgeFillMaxExpansionPx':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers
                  .add('invalid_effect_value:${value.propertyDefinitionId}');
              continue;
            }
            edgeFill = _applyEdgeFillScalar(
              edgeFill,
              propertyId: value.propertyDefinitionId,
              rendererScalar: rendererScalar,
              enabledWasAuthored: edgeFillEnabledWasAuthored,
            );
          case 'tileOutputScale':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers
                  .add('invalid_effect_value:${value.propertyDefinitionId}');
              continue;
            }
            effectsById[value.propertyDefinitionId] = MasterVisualEffectBinding(
              id: value.propertyDefinitionId,
              rendererValue: rendererScalar,
              rendererUnit: value.mapping.rendererUnit,
            );
          case 'gaussianBlur':
          case 'blurHorizontal':
          case 'blurVertical':
          case 'blurMix':
          case 'blurEdgeMode':
          case 'blurCrop':
          case 'shadowOpacity':
          case 'shadowBlur':
          case 'shadowOffsetX':
          case 'shadowOffsetY':
          case 'shadowSpread':
            if (rendererScalar == null || !rendererScalar.isFinite) {
              blockers
                  .add('invalid_effect_value:${value.propertyDefinitionId}');
              continue;
            }
            effectsById[value.propertyDefinitionId] = MasterVisualEffectBinding(
              id: value.propertyDefinitionId,
              rendererValue: rendererScalar,
              rendererUnit: value.mapping.rendererUnit,
            );
          default:
            blockers.add(
              'unsupported_property:${value.propertyDefinitionId}:${value.sourceChannelId}',
            );
        }
      }

      final explicitEffectIds = frame.effectParameters.keys;
      for (final effectId in explicitEffectIds) {
        if (_motionBlurPropertyIds.contains(effectId)) {
          final mapping = frame.effectParameters[effectId];
          if (mapping == null) {
            blockers.add('invalid_effect_value:$effectId');
            continue;
          }
          final rendererScalar = mapping.renderer.scalar;
          final rendererBool = mapping.renderer.booleanValue;
          if (effectId == 'motionBlurEnabled' ||
              effectId == 'motionBlurAffectPosition' ||
              effectId == 'motionBlurAffectScale' ||
              effectId == 'motionBlurAffectRotation') {
            if (rendererBool == null) {
              blockers.add('invalid_effect_value:$effectId');
              continue;
            }
            if (effectId == 'motionBlurEnabled') {
              motionBlurEnabledWasAuthored = true;
            }
            motionBlur = _applyMotionBlurBoolean(
              motionBlur,
              propertyId: effectId,
              rendererBool: rendererBool,
            );
            continue;
          }
          if (rendererScalar == null || !rendererScalar.isFinite) {
            blockers.add('invalid_effect_value:$effectId');
            continue;
          }
          motionBlur = _applyMotionBlurScalar(
            motionBlur,
            propertyId: effectId,
            rendererScalar: rendererScalar,
            enabledWasAuthored: motionBlurEnabledWasAuthored,
          );
          continue;
        }
        if (_edgeFillPropertyIds.contains(effectId)) {
          final mapping = frame.effectParameters[effectId];
          if (mapping == null) {
            blockers.add('invalid_effect_value:$effectId');
            continue;
          }
          final rendererScalar = mapping.renderer.scalar;
          final rendererBool = mapping.renderer.booleanValue;
          if (effectId == 'edgeFillEnabled' ||
              effectId == 'edgeFillAffectRotation' ||
              effectId == 'edgeFillAffectScale' ||
              effectId == 'edgeFillAffectPosition' ||
              effectId == 'edgeFillAffectMotionBlur') {
            if (rendererBool == null) {
              blockers.add('invalid_effect_value:$effectId');
              continue;
            }
            if (effectId == 'edgeFillEnabled') {
              edgeFillEnabledWasAuthored = true;
            }
            edgeFill = _applyEdgeFillBoolean(
              edgeFill,
              propertyId: effectId,
              rendererBool: rendererBool,
            );
            continue;
          }
          if (rendererScalar == null || !rendererScalar.isFinite) {
            blockers.add('invalid_effect_value:$effectId');
            continue;
          }
          edgeFill = _applyEdgeFillScalar(
            edgeFill,
            propertyId: effectId,
            rendererScalar: rendererScalar,
            enabledWasAuthored: edgeFillEnabledWasAuthored,
          );
          continue;
        }
        if (_supportedEffectIds.contains(effectId)) {
          final mapping = frame.effectParameters[effectId];
          final rendererScalar = mapping?.renderer.scalar;
          if (mapping != null &&
              rendererScalar != null &&
              rendererScalar.isFinite) {
            effectsById[effectId] = MasterVisualEffectBinding(
              id: effectId,
              rendererValue: rendererScalar,
              rendererUnit: mapping.rendererUnit,
            );
          } else {
            blockers.add('invalid_effect_value:$effectId');
          }
          continue;
        }
        blockers.add('unsupported_effect:$effectId');
      }

      final sourceKind = source?.kind ?? MasterVisualSourceKind.unknown;
      if (source == null) {
        blockers.add('missing_source_binding:$targetId');
      }

      surfaces.add(
        MasterVisualSurface(
          targetId: targetId,
          sourceKind: sourceKind,
          source: source,
          drawOrder: drawOrderByTargetId[targetId] ?? 0,
          transitionRole: transitionRolesByTargetId[targetId] ??
              MasterVisualTransitionRole.none,
          transform: transform,
          crop: crop,
          mask: mask,
          colors: colors,
          textStyle: textStyle,
          shapeStyle: shapeStyle,
          opacity: opacity,
          motionBlur: motionBlur,
          edgeFill: edgeFill,
          effects: effectsById.values.toList(growable: false),
          blockers: blockers,
        ),
      );
      globalBlockers.addAll(blockers);
    }

    final transitionState = MasterVisualTransitionState(
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
    return MasterVisualProgram(
      time: frame.time,
      surfaces: surfaces,
      blockers: globalBlockers,
      diagnostics: globalDiagnostics,
      transitionState: transitionState,
    );
  }

  MasterMotionBlurPolicy _applyMotionBlurScalar(
    MasterMotionBlurPolicy policy, {
    required String propertyId,
    required double rendererScalar,
    required bool enabledWasAuthored,
  }) {
    switch (propertyId) {
      case 'motionBlurAmount':
        final amount = rendererScalar.clamp(0.0, 1.0).toDouble();
        return policy.copyWith(
          amount: amount,
          enabled: enabledWasAuthored ? policy.enabled : amount > 0,
        );
      case 'motionBlurShutterAngle':
        return policy.copyWith(
          shutterAngleDegrees: rendererScalar.clamp(0.0, 1440.0).toDouble(),
        );
      case 'motionBlurShutterPhase':
        return policy.copyWith(
          shutterPhaseDegrees: rendererScalar.clamp(-720.0, 720.0).toDouble(),
        );
      case 'motionBlurSamples':
        return policy.copyWith(
          samples: rendererScalar.round().clamp(1, 64),
        );
      case 'motionBlurAdaptiveSampleLimit':
        return policy.copyWith(
          adaptiveSampleLimit: rendererScalar.round().clamp(1, 128),
        );
      case 'motionBlurMaxTrailPx':
        return policy.copyWith(
          maxTrailPx: rendererScalar.clamp(0.0, 4096.0).toDouble(),
        );
      default:
        return policy;
    }
  }

  MasterMotionBlurPolicy _applyMotionBlurBoolean(
    MasterMotionBlurPolicy policy, {
    required String propertyId,
    required bool rendererBool,
  }) {
    switch (propertyId) {
      case 'motionBlurEnabled':
        return policy.copyWith(enabled: rendererBool);
      case 'motionBlurAffectPosition':
        return policy.copyWith(affectPosition: rendererBool);
      case 'motionBlurAffectScale':
        return policy.copyWith(affectScale: rendererBool);
      case 'motionBlurAffectRotation':
        return policy.copyWith(affectRotation: rendererBool);
      default:
        return policy;
    }
  }

  MasterEdgeFillPolicy _applyEdgeFillScalar(
    MasterEdgeFillPolicy policy, {
    required String propertyId,
    required double rendererScalar,
    required bool enabledWasAuthored,
  }) {
    switch (propertyId) {
      case 'edgeFillAmount':
        final amount = rendererScalar.clamp(0.0, 1.0).toDouble();
        return policy.copyWith(
          amount: amount,
          enabled: enabledWasAuthored ? policy.enabled : amount > 0.0001,
        );
      case 'edgeFillMode':
        final modeIndex = rendererScalar.round().clamp(0, 7);
        return policy.copyWith(
          mode: MasterEdgeFillMode.values[modeIndex],
        );
      case 'edgeFillOverscanScale':
        return policy.copyWith(
          overscanScale: rendererScalar.clamp(1.0, 10.0).toDouble(),
        );
      case 'edgeFillSoftnessPx':
        return policy.copyWith(
          softnessPx: rendererScalar.clamp(0.0, 1024.0).toDouble(),
        );
      case 'edgeFillBlurSigmaPx':
        return policy.copyWith(
          blurSigmaPx: rendererScalar.clamp(0.0, 512.0).toDouble(),
        );
      case 'edgeFillMaxExpansionPx':
        return policy.copyWith(
          maxExpansionPx: rendererScalar.clamp(0.0, 8192.0).toDouble(),
        );
      default:
        return policy;
    }
  }

  MasterEdgeFillPolicy _applyEdgeFillBoolean(
    MasterEdgeFillPolicy policy, {
    required String propertyId,
    required bool rendererBool,
  }) {
    switch (propertyId) {
      case 'edgeFillEnabled':
        return policy.copyWith(enabled: rendererBool);
      case 'edgeFillAffectRotation':
        return policy.copyWith(affectRotation: rendererBool);
      case 'edgeFillAffectScale':
        return policy.copyWith(affectScale: rendererBool);
      case 'edgeFillAffectPosition':
        return policy.copyWith(affectPosition: rendererBool);
      case 'edgeFillAffectMotionBlur':
        return policy.copyWith(affectMotionBlur: rendererBool);
      default:
        return policy;
    }
  }

  List<String> _orderedTargetIds({
    required Set<String> targetIds,
    required List<String> visibleLayerIds,
  }) {
    final ordered = <String>[];
    final seen = <String>{};
    for (final targetId in visibleLayerIds) {
      if (!targetIds.contains(targetId)) {
        continue;
      }
      if (seen.add(targetId)) {
        ordered.add(targetId);
      }
    }
    final leftovers = targetIds.where((id) => !seen.contains(id)).toList()
      ..sort();
    ordered.addAll(leftovers);
    return ordered;
  }
}
