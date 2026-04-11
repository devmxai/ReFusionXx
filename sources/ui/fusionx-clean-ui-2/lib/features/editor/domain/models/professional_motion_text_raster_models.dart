import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'export_motion_text_program_models.dart';
import 'professional_motion_models.dart';
import 'professional_motion_text_models.dart';
import 'professional_motion_text_render_models.dart';

const double kMotionTextRasterBlurSigmaScale = 0.18;
const double kMotionTextRasterBlurSpreadMultiplier = 3.0;
const double kMotionTextRasterMinimumLayoutPaddingPx = 2.0;
const double kMotionTextRasterMinimumFontSizePx = 12.0;
const double kMotionTextRasterFontPaddingRatio = 0.08;
const String kMotionTextRasterContractVersion = 'motion-text-raster.v1alpha1';

@immutable
class MotionTextRasterizationPolicy {
  const MotionTextRasterizationPolicy({
    this.blurSigmaScale = kMotionTextRasterBlurSigmaScale,
    this.blurSpreadMultiplier = kMotionTextRasterBlurSpreadMultiplier,
    this.minimumLayoutPaddingPx = kMotionTextRasterMinimumLayoutPaddingPx,
    this.minimumFontSizePx = kMotionTextRasterMinimumFontSizePx,
    this.fontPaddingRatio = kMotionTextRasterFontPaddingRatio,
  });

  final double blurSigmaScale;
  final double blurSpreadMultiplier;
  final double minimumLayoutPaddingPx;
  final double minimumFontSizePx;
  final double fontPaddingRatio;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'blurSigmaScale': blurSigmaScale,
        'blurSpreadMultiplier': blurSpreadMultiplier,
        'minimumLayoutPaddingPx': minimumLayoutPaddingPx,
        'minimumFontSizePx': minimumFontSizePx,
        'fontPaddingRatio': fontPaddingRatio,
      };
}

const MotionTextRasterizationPolicy kDefaultMotionTextRasterizationPolicy =
    MotionTextRasterizationPolicy();

@immutable
class MotionTextRasterContract {
  const MotionTextRasterContract({
    this.contractVersion = kMotionTextRasterContractVersion,
    this.rasterizationPolicy = kDefaultMotionTextRasterizationPolicy,
    this.layoutEngineId = 'shaped_paragraph_layout',
    this.blurEngineId = 'gaussian_layer_blur',
    this.blurColorResolutionMode = 'alpha_mask_colorized',
  });

  final String contractVersion;
  final MotionTextRasterizationPolicy rasterizationPolicy;
  final String layoutEngineId;
  final String blurEngineId;
  final String blurColorResolutionMode;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'contractVersion': contractVersion,
        'layoutEngineId': layoutEngineId,
        'blurEngineId': blurEngineId,
        'blurColorResolutionMode': blurColorResolutionMode,
        'rasterizationPolicy': rasterizationPolicy.toBridgeMap(),
      };
}

@immutable
class MotionTextRasterExportProgramNode {
  MotionTextRasterExportProgramNode({
    required this.id,
    required this.targetElementId,
    required this.sceneId,
    required this.layerId,
    required this.projectRange,
    required this.fullText,
    required this.revealUnit,
    required this.typography,
    required this.effects,
    required this.layout,
    required this.layerOpacity,
    required List<String> animationKinds,
    required List<ExportMotionTextProgramAnimationBlock> animationBlocks,
    required List<ExportMotionScalarChannel> channels,
    required List<ExportMotionScalarChannel> layerChannels,
    this.name,
    this.presetId,
  })  : animationKinds = List.unmodifiable(animationKinds),
        animationBlocks = List.unmodifiable(animationBlocks),
        channels = List.unmodifiable(channels),
        layerChannels = List.unmodifiable(layerChannels);

  final String id;
  final String targetElementId;
  final String sceneId;
  final String layerId;
  final TimelineTimeRange projectRange;
  final String fullText;
  final String revealUnit;
  final MotionTextTypographyContract typography;
  final MotionTextEffectsContract effects;
  final MotionTextLayoutContract layout;
  final double layerOpacity;
  final List<String> animationKinds;
  final List<ExportMotionTextProgramAnimationBlock> animationBlocks;
  final List<ExportMotionScalarChannel> channels;
  final List<ExportMotionScalarChannel> layerChannels;
  final String? name;
  final String? presetId;

  List<String> get channelPropertyIds => List<String>.unmodifiable(
        channels.map((channel) => channel.propertyId),
      );

  List<String> get layerChannelPropertyIds => List<String>.unmodifiable(
        layerChannels.map((channel) => channel.propertyId),
      );

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'id': id,
        'targetElementId': targetElementId,
        'sceneId': sceneId,
        'layerId': layerId,
        'projectRange': <String, Object?>{
          'startMs': projectRange.start.inMilliseconds,
          'durationMs': projectRange.duration.inMilliseconds,
          'endExclusiveMs': projectRange.endExclusive.inMilliseconds,
        },
        'fullText': fullText,
        'revealUnit': revealUnit,
        'typography': typography.toBridgeMap(),
        'effects': effects.toBridgeMap(),
        'layout': layout.toBridgeMap(),
        'layerOpacity': layerOpacity,
        'animationKinds': animationKinds,
        'animationBlocks': animationBlocks
            .map((block) => block.toBridgeMap())
            .toList(growable: false),
        'channels': channels
            .map((channel) => channel.toBridgeMap())
            .toList(growable: false),
        'layerChannels': layerChannels
            .map((channel) => channel.toBridgeMap())
            .toList(growable: false),
        'channelPropertyIds': channelPropertyIds,
        'layerChannelPropertyIds': layerChannelPropertyIds,
        'name': name,
        'presetId': presetId,
      };
}

@immutable
class MotionTextRasterExportProgram {
  MotionTextRasterExportProgram({
    required this.contract,
    required this.canvasSize,
    required List<MotionTextRasterExportProgramNode> nodes,
  }) : nodes = List.unmodifiable(nodes);

  final MotionTextRasterContract contract;
  final MotionSize2D canvasSize;
  final List<MotionTextRasterExportProgramNode> nodes;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'contractVersion': contract.contractVersion,
        'layoutEngineId': contract.layoutEngineId,
        'blurEngineId': contract.blurEngineId,
        'blurColorResolutionMode': contract.blurColorResolutionMode,
        'canvasSize': <String, Object?>{
          'width': canvasSize.width,
          'height': canvasSize.height,
        },
        'rasterizationPolicy': contract.rasterizationPolicy.toBridgeMap(),
        'nodes': nodes.map((node) => node.toBridgeMap()).toList(),
      };
}

@immutable
class MotionTextTypographyContract {
  const MotionTextTypographyContract({
    required this.fontSize,
    required this.letterSpacing,
    required this.colorArgb,
    required this.fontFamily,
    required this.fontWeight,
    required this.fontStyle,
    required this.lineHeight,
    required this.textAlignment,
  });

  final double fontSize;
  final double letterSpacing;
  final int colorArgb;
  final String? fontFamily;
  final int fontWeight;
  final String fontStyle;
  final double lineHeight;
  final String textAlignment;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'fontSize': fontSize,
        'letterSpacing': letterSpacing,
        'colorArgb': colorArgb,
        'fontFamily': fontFamily,
        'fontWeight': fontWeight,
        'fontStyle': fontStyle,
        'lineHeight': lineHeight,
        'textAlignment': textAlignment,
      };
}

@immutable
class MotionTextEffectsContract {
  const MotionTextEffectsContract({
    required this.opacity,
    required this.blurAmount,
    required this.blendMode,
  });

  final double opacity;
  final double blurAmount;
  final MotionBlendMode blendMode;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'opacity': opacity,
        'blurAmount': blurAmount,
        'blendMode': blendMode.name,
      };
}

@immutable
class MotionTextLayoutContract {
  const MotionTextLayoutContract({
    required this.canvasOffset,
    required this.scaleX,
    required this.scaleY,
    required this.rotationDegrees,
    required this.anchor,
    required this.zIndex,
  });

  final MotionPoint2D canvasOffset;
  final double scaleX;
  final double scaleY;
  final double rotationDegrees;
  final String anchor;
  final int zIndex;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'canvasOffset': <String, Object?>{
          'x': canvasOffset.x,
          'y': canvasOffset.y,
        },
        'scaleX': scaleX,
        'scaleY': scaleY,
        'rotationDegrees': rotationDegrees,
        'anchor': anchor,
        'zIndex': zIndex,
      };
}

@immutable
class MotionTextResolvedRasterMetrics {
  const MotionTextResolvedRasterMetrics({
    required this.effectiveScale,
    required this.translatedX,
    required this.translatedY,
    required this.fontSizePx,
    required this.letterSpacingPx,
    required this.blurSigma,
    required this.blurKernelSpreadPx,
    required this.layoutPaddingPx,
  });

  final double effectiveScale;
  final double translatedX;
  final double translatedY;
  final double fontSizePx;
  final double letterSpacingPx;
  final double blurSigma;
  final double blurKernelSpreadPx;
  final double layoutPaddingPx;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'effectiveScale': effectiveScale,
        'translatedX': translatedX,
        'translatedY': translatedY,
        'fontSizePx': fontSizePx,
        'letterSpacingPx': letterSpacingPx,
        'blurSigma': blurSigma,
        'blurKernelSpreadPx': blurKernelSpreadPx,
        'layoutPaddingPx': layoutPaddingPx,
      };
}

@immutable
class MotionTextRasterNode {
  MotionTextRasterNode({
    required this.id,
    required this.targetElementId,
    required this.sceneId,
    required this.layerId,
    required this.projectRange,
    required this.isActive,
    required this.text,
    required this.fullText,
    required this.revealUnit,
    required this.revealProgress,
    required this.hasRevealAnimation,
    required List<MotionTextAnimationKind> animationKinds,
    required Map<MotionTextAnimationKind, double> animationProgressByKind,
    required this.typography,
    required this.effects,
    required this.layout,
    this.name,
    this.presetId,
  })  : animationKinds = List.unmodifiable(animationKinds),
        animationProgressByKind = Map.unmodifiable(animationProgressByKind);

  final String id;
  final String targetElementId;
  final String sceneId;
  final String layerId;
  final TimelineTimeRange projectRange;
  final bool isActive;
  final String text;
  final String fullText;
  final MotionTextRevealUnit revealUnit;
  final double? revealProgress;
  final bool hasRevealAnimation;
  final List<MotionTextAnimationKind> animationKinds;
  final Map<MotionTextAnimationKind, double> animationProgressByKind;
  final MotionTextTypographyContract typography;
  final MotionTextEffectsContract effects;
  final MotionTextLayoutContract layout;
  final String? name;
  final String? presetId;

  MotionTextResolvedRasterMetrics resolveMetrics({
    required double scaleX,
    required double scaleY,
    MotionTextRasterizationPolicy policy =
        kDefaultMotionTextRasterizationPolicy,
  }) {
    final effectiveScale = math.min(scaleX, scaleY);
    final translatedX = layout.canvasOffset.x * scaleX;
    final translatedY = layout.canvasOffset.y * scaleY;
    final fontSizePx = (typography.fontSize * effectiveScale).clamp(
      policy.minimumFontSizePx,
      double.infinity,
    );
    final letterSpacingPx = typography.letterSpacing * effectiveScale;
    final blurSigma =
        effects.blurAmount * policy.blurSigmaScale * effectiveScale;
    final blurKernelSpreadPx =
        math.max(0.0, blurSigma * policy.blurSpreadMultiplier);
    final layoutPaddingPx = math
        .max(
          policy.minimumLayoutPaddingPx,
          math.max(
            blurKernelSpreadPx,
            math.max(
              letterSpacingPx.abs(),
              fontSizePx * policy.fontPaddingRatio,
            ),
          ),
        )
        .ceilToDouble();
    return MotionTextResolvedRasterMetrics(
      effectiveScale: effectiveScale,
      translatedX: translatedX,
      translatedY: translatedY,
      fontSizePx: fontSizePx,
      letterSpacingPx: letterSpacingPx,
      blurSigma: blurSigma,
      blurKernelSpreadPx: blurKernelSpreadPx,
      layoutPaddingPx: layoutPaddingPx,
    );
  }

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'id': id,
        'targetElementId': targetElementId,
        'sceneId': sceneId,
        'layerId': layerId,
        'projectRange': <String, Object?>{
          'startMs': projectRange.start.inMilliseconds,
          'durationMs': projectRange.duration.inMilliseconds,
          'endExclusiveMs': projectRange.endExclusive.inMilliseconds,
        },
        'isActive': isActive,
        'text': text,
        'fullText': fullText,
        'revealUnit': revealUnit.name,
        'revealProgress': revealProgress,
        'hasRevealAnimation': hasRevealAnimation,
        'animationKinds': animationKinds.map((kind) => kind.name).toList(),
        'animationProgressByKind': animationProgressByKind.map(
          (kind, progress) => MapEntry<String, Object?>(kind.name, progress),
        ),
        'typography': typography.toBridgeMap(),
        'effects': effects.toBridgeMap(),
        'layout': layout.toBridgeMap(),
        'name': name,
        'presetId': presetId,
      };
}

@immutable
class MotionTextRasterSnapshot {
  MotionTextRasterSnapshot({
    required this.projectId,
    required this.time,
    required this.canvasSize,
    required this.contract,
    required List<MotionTextRasterNode> nodes,
  }) : nodes = List.unmodifiable(nodes);

  final String projectId;
  final TimelineTime time;
  final MotionSize2D canvasSize;
  final MotionTextRasterContract contract;
  final List<MotionTextRasterNode> nodes;

  MotionTextRasterizationPolicy get rasterizationPolicy =>
      contract.rasterizationPolicy;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'projectId': projectId,
        'timeMs': time.inMilliseconds,
        'canvasSize': <String, Object?>{
          'width': canvasSize.width,
          'height': canvasSize.height,
        },
        'contract': contract.toBridgeMap(),
        'rasterizationPolicy': rasterizationPolicy.toBridgeMap(),
        'nodes': nodes.map((node) => node.toBridgeMap()).toList(),
      };
}

abstract class MotionTextRasterContractAdapter {
  const MotionTextRasterContractAdapter();

  MotionTextRasterSnapshot adapt({
    required MotionTextRenderSnapshot snapshot,
  });
}

class BasicMotionTextRasterContractAdapter
    implements MotionTextRasterContractAdapter {
  const BasicMotionTextRasterContractAdapter({
    this.contract = const MotionTextRasterContract(),
  });

  final MotionTextRasterContract contract;

  @override
  MotionTextRasterSnapshot adapt({
    required MotionTextRenderSnapshot snapshot,
  }) {
    return MotionTextRasterSnapshot(
      projectId: snapshot.projectId,
      time: snapshot.time,
      canvasSize: snapshot.canvasSize,
      contract: contract,
      nodes: snapshot.nodes
          .map(
            (node) => MotionTextRasterNode(
              id: node.id,
              targetElementId: node.targetElementId,
              sceneId: node.sceneId,
              layerId: node.layerId,
              projectRange: node.projectRange,
              isActive: node.isActive,
              text: node.text,
              fullText: node.fullText,
              revealUnit: node.revealUnit,
              revealProgress: node.revealProgress,
              hasRevealAnimation: node.hasRevealAnimation,
              animationKinds: node.animationKinds,
              animationProgressByKind: node.animationProgressByKind,
              typography: MotionTextTypographyContract(
                fontSize: node.fontSize,
                letterSpacing: node.letterSpacing,
                colorArgb: node.colorArgb,
                fontFamily: node.fontFamily,
                fontWeight: node.fontWeight,
                fontStyle: node.fontStyle,
                lineHeight: node.lineHeight,
                textAlignment: node.textAlignment,
              ),
              effects: MotionTextEffectsContract(
                opacity: node.opacity,
                blurAmount: node.blurAmount,
                blendMode: node.blendMode,
              ),
              layout: MotionTextLayoutContract(
                canvasOffset: node.canvasOffset,
                scaleX: node.scaleX,
                scaleY: node.scaleY,
                rotationDegrees: node.rotationDegrees,
                anchor: node.anchor,
                zIndex: node.zIndex,
              ),
              name: node.name,
              presetId: node.presetId,
            ),
          )
          .toList(growable: false),
    );
  }
}

MotionTextRasterExportProgram? buildMotionTextRasterExportProgram({
  required MotionTextRasterContract? contract,
  required ExportMotionTextProgram? motionTextProgram,
}) {
  if (contract == null ||
      motionTextProgram == null ||
      motionTextProgram.nodes.isEmpty) {
    return null;
  }
  return MotionTextRasterExportProgram(
    contract: contract,
    canvasSize: motionTextProgram.canvasSize,
    nodes: motionTextProgram.nodes
        .map(
          (node) => MotionTextRasterExportProgramNode(
            id: node.id,
            targetElementId: node.targetElementId,
            sceneId: node.sceneId,
            layerId: node.layerId,
            projectRange: node.projectRange,
            fullText: node.fullText,
            revealUnit: node.revealUnit,
            typography: MotionTextTypographyContract(
              fontSize: node.baseFontSize,
              letterSpacing: node.baseLetterSpacing,
              colorArgb: node.colorArgb,
              fontFamily: node.fontFamily,
              fontWeight: node.fontWeight,
              fontStyle: node.fontStyle,
              lineHeight: node.lineHeight,
              textAlignment: node.textAlignment,
            ),
            effects: MotionTextEffectsContract(
              opacity: node.baseOpacity,
              blurAmount: node.baseBlurAmount,
              blendMode: _motionBlendModeFromName(node.blendMode),
            ),
            layout: MotionTextLayoutContract(
              canvasOffset: MotionPoint2D(
                x: node.basePositionX,
                y: node.basePositionY,
              ),
              scaleX: node.baseScaleX,
              scaleY: node.baseScaleY,
              rotationDegrees: node.baseRotationDegrees,
              anchor: node.anchor,
              zIndex: node.zIndex,
            ),
            layerOpacity: node.layerOpacity,
            animationKinds: node.animationKinds,
            animationBlocks: node.animationBlocks,
            channels: node.channels,
            layerChannels: node.layerChannels,
            name: node.name,
            presetId: node.presetId,
          ),
        )
        .toList(growable: false),
  );
}

MotionBlendMode _motionBlendModeFromName(String name) {
  for (final value in MotionBlendMode.values) {
    if (value.name == name) {
      return value;
    }
  }
  return MotionBlendMode.normal;
}
