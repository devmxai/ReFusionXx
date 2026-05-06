import 'dart:math' as math;

import '../models/master_value_truth_models.dart';
import '../models/professional_motion_models.dart';

class MasterValueTruthRegistry {
  MasterValueTruthRegistry({
    Map<String, MasterPropertyDefinition>? definitions,
  }) : _definitions = definitions ?? _buildDefaultDefinitions();

  final Map<String, MasterPropertyDefinition> _definitions;

  Iterable<MasterPropertyDefinition> get definitions => _definitions.values;

  MasterPropertyDefinition? definitionById(String id) {
    return _definitions[id];
  }

  MasterPropertyDefinition? definitionForMotionProperty(
    MotionPropertyDefinition definition,
  ) {
    final key = definition.path.canonicalKey;
    if (key == 'visual.opacity') {
      return _definitions['opacity'];
    }
    if (key == 'transform.scale.x' || key == 'transform.scale.y') {
      return _definitions['scale'];
    }
    if (key == 'transform.position.x' || key == 'transform.position.y') {
      return _definitions['position'];
    }
    if (key == 'transform.rotation.degrees') {
      return _definitions['rotation'];
    }
    if (key == 'visual.blur.amount') {
      return _definitions['gaussianBlur'];
    }
    if (key == 'visual.blur.horizontal') {
      return _definitions['blurHorizontal'];
    }
    if (key == 'visual.blur.vertical') {
      return _definitions['blurVertical'];
    }
    if (key == 'visual.blur.mix') {
      return _definitions['blurMix'];
    }
    if (key == 'visual.blur.edgeMode') {
      return _definitions['blurEdgeMode'];
    }
    if (key == 'visual.blur.crop') {
      return _definitions['blurCrop'];
    }
    if (key == 'effect.motionBlur.enabled') {
      return _definitions['motionBlurEnabled'];
    }
    if (key == 'effect.motionBlur.amount') {
      return _definitions['motionBlurAmount'];
    }
    if (key == 'effect.motionBlur.shutterAngle') {
      return _definitions['motionBlurShutterAngle'];
    }
    if (key == 'effect.motionBlur.shutterPhase') {
      return _definitions['motionBlurShutterPhase'];
    }
    if (key == 'effect.motionBlur.samples') {
      return _definitions['motionBlurSamples'];
    }
    if (key == 'effect.motionBlur.adaptiveSampleLimit') {
      return _definitions['motionBlurAdaptiveSampleLimit'];
    }
    if (key == 'effect.motionBlur.maxTrailPx') {
      return _definitions['motionBlurMaxTrailPx'];
    }
    if (key == 'effect.motionBlur.affectPosition') {
      return _definitions['motionBlurAffectPosition'];
    }
    if (key == 'effect.motionBlur.affectScale') {
      return _definitions['motionBlurAffectScale'];
    }
    if (key == 'effect.motionBlur.affectRotation') {
      return _definitions['motionBlurAffectRotation'];
    }
    if (key == 'effect.edgeFill.enabled') {
      return _definitions['edgeFillEnabled'];
    }
    if (key == 'effect.edgeFill.amount') {
      return _definitions['edgeFillAmount'];
    }
    if (key == 'effect.edgeFill.mode') {
      return _definitions['edgeFillMode'];
    }
    if (key == 'effect.edgeFill.overscanScale') {
      return _definitions['edgeFillOverscanScale'];
    }
    if (key == 'effect.edgeFill.softnessPx') {
      return _definitions['edgeFillSoftnessPx'];
    }
    if (key == 'effect.edgeFill.blurSigmaPx') {
      return _definitions['edgeFillBlurSigmaPx'];
    }
    if (key == 'effect.edgeFill.maxExpansionPx') {
      return _definitions['edgeFillMaxExpansionPx'];
    }
    if (key == 'effect.edgeFill.affectRotation') {
      return _definitions['edgeFillAffectRotation'];
    }
    if (key == 'effect.edgeFill.affectScale') {
      return _definitions['edgeFillAffectScale'];
    }
    if (key == 'effect.edgeFill.affectPosition') {
      return _definitions['edgeFillAffectPosition'];
    }
    if (key == 'effect.edgeFill.affectMotionBlur') {
      return _definitions['edgeFillAffectMotionBlur'];
    }
    if (key == 'effect.shadow.opacity') {
      return _definitions['shadowOpacity'];
    }
    if (key == 'effect.shadow.blur') {
      return _definitions['shadowBlur'];
    }
    if (key == 'effect.shadowOffset.x') {
      return _definitions['shadowOffsetX'];
    }
    if (key == 'effect.shadowOffset.y') {
      return _definitions['shadowOffsetY'];
    }
    if (key == 'effect.shadow.spread') {
      return _definitions['shadowSpread'];
    }
    if (key == 'effect.shadow.color') {
      return _definitions['shadowColor'];
    }
    if (key == 'visual.color') {
      return _definitions['visualColor'];
    }
    if (key == 'shape.maskRevealProgress') {
      return _definitions['maskRevealProgress'];
    }
    if (key == 'shape.trim.start') {
      return _definitions['trimStart'];
    }
    if (key == 'shape.trim.end') {
      return _definitions['trimEnd'];
    }
    if (key == 'shape.trim.offset') {
      return _definitions['trimOffset'];
    }
    if (key == 'crop.rect') {
      return _definitions['cropRect'];
    }
    if (key == 'shape.width') {
      return _definitions['shapeWidth'];
    }
    if (key == 'shape.height') {
      return _definitions['shapeHeight'];
    }
    if (key == 'shape.cornerRadius') {
      return _definitions['shapeCornerRadius'];
    }
    if (key == 'text.fontSize') {
      return _definitions['textFontSize'];
    }
    if (key == 'text.fontWeight') {
      return _definitions['textFontWeight'];
    }
    if (key == 'text.fontFamily') {
      return _definitions['textFontFamily'];
    }
    if (key == 'text.fontStyle') {
      return _definitions['textFontStyle'];
    }
    if (key == 'text.lineHeight') {
      return _definitions['textLineHeight'];
    }
    if (key == 'text.alignment') {
      return _definitions['textAlignment'];
    }
    if (key == 'text.letterSpacing') {
      return _definitions['textLetterSpacing'];
    }
    if (key == 'text.revealProgress') {
      return _definitions['textRevealProgress'];
    }
    return null;
  }

  MasterPropertyValueMapping mapValue({
    required MasterPropertyDefinition definition,
    required MotionPropertyValue value,
  }) {
    return definition.mapper(value);
  }

  static Map<String, MasterPropertyDefinition> _buildDefaultDefinitions() {
    return <String, MasterPropertyDefinition>{
      'opacity': const MasterPropertyDefinition(
        id: 'opacity',
        category: MasterPropertyCategory.visual,
        valueType: MasterValueType.percent,
        uiUnit: MasterValueUnit.percentUi,
        engineUnit: MasterValueUnit.normalized01,
        rendererUnit: MasterValueUnit.normalized01,
        defaultValue: MotionPropertyValue.scalar(100),
        minValue: 0,
        maxValue: 100,
        mapper: _mapOpacity,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'scale': const MasterPropertyDefinition(
        id: 'scale',
        category: MasterPropertyCategory.transform,
        valueType: MasterValueType.signedPercent,
        uiUnit: MasterValueUnit.signedPercentUi,
        engineUnit: MasterValueUnit.multiplier,
        rendererUnit: MasterValueUnit.multiplier,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: -95,
        maxValue: 500,
        mapper: _mapScale,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'position': const MasterPropertyDefinition(
        id: 'position',
        category: MasterPropertyCategory.transform,
        valueType: MasterValueType.dimension,
        uiUnit: MasterValueUnit.canvasPx,
        engineUnit: MasterValueUnit.canvasPx,
        rendererUnit: MasterValueUnit.devicePx,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: -100000,
        maxValue: 100000,
        mapper: _mapPosition,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'rotation': const MasterPropertyDefinition(
        id: 'rotation',
        category: MasterPropertyCategory.transform,
        valueType: MasterValueType.degrees,
        uiUnit: MasterValueUnit.degrees,
        engineUnit: MasterValueUnit.degrees,
        rendererUnit: MasterValueUnit.radians,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: -36000,
        maxValue: 36000,
        mapper: _mapRotation,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'gaussianBlur': const MasterPropertyDefinition(
        id: 'gaussianBlur',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.dimension,
        uiUnit: MasterValueUnit.canvasPx,
        engineUnit: MasterValueUnit.canvasPx,
        rendererUnit: MasterValueUnit.shaderSigmaPx,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: 0,
        maxValue: 512,
        mapper: _mapGaussianBlur,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'blurHorizontal': const MasterPropertyDefinition(
        id: 'blurHorizontal',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.percent,
        uiUnit: MasterValueUnit.percentUi,
        engineUnit: MasterValueUnit.normalized01,
        rendererUnit: MasterValueUnit.normalized01,
        defaultValue: MotionPropertyValue.scalar(100),
        minValue: 0,
        maxValue: 100,
        mapper: _mapPercent01,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'blurVertical': const MasterPropertyDefinition(
        id: 'blurVertical',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.percent,
        uiUnit: MasterValueUnit.percentUi,
        engineUnit: MasterValueUnit.normalized01,
        rendererUnit: MasterValueUnit.normalized01,
        defaultValue: MotionPropertyValue.scalar(100),
        minValue: 0,
        maxValue: 100,
        mapper: _mapPercent01,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'blurMix': const MasterPropertyDefinition(
        id: 'blurMix',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.percent,
        uiUnit: MasterValueUnit.percentUi,
        engineUnit: MasterValueUnit.normalized01,
        rendererUnit: MasterValueUnit.normalized01,
        defaultValue: MotionPropertyValue.scalar(100),
        minValue: 0,
        maxValue: 100,
        mapper: _mapPercent01,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'blurEdgeMode': const MasterPropertyDefinition(
        id: 'blurEdgeMode',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.scalar,
        uiUnit: MasterValueUnit.enumToken,
        engineUnit: MasterValueUnit.enumToken,
        rendererUnit: MasterValueUnit.enumToken,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: 0,
        maxValue: 8,
        mapper: _mapScalar,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'blurCrop': const MasterPropertyDefinition(
        id: 'blurCrop',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.percent,
        uiUnit: MasterValueUnit.percentUi,
        engineUnit: MasterValueUnit.normalized01,
        rendererUnit: MasterValueUnit.normalized01,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: 0,
        maxValue: 100,
        mapper: _mapPercent01,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'shadowOpacity': const MasterPropertyDefinition(
        id: 'shadowOpacity',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.percent,
        uiUnit: MasterValueUnit.percentUi,
        engineUnit: MasterValueUnit.normalized01,
        rendererUnit: MasterValueUnit.normalized01,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: 0,
        maxValue: 100,
        mapper: _mapPercent01,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'shadowBlur': const MasterPropertyDefinition(
        id: 'shadowBlur',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.dimension,
        uiUnit: MasterValueUnit.canvasPx,
        engineUnit: MasterValueUnit.canvasPx,
        rendererUnit: MasterValueUnit.shaderSigmaPx,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: 0,
        maxValue: 512,
        mapper: _mapGaussianBlur,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'shadowOffsetX': const MasterPropertyDefinition(
        id: 'shadowOffsetX',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.dimension,
        uiUnit: MasterValueUnit.canvasPx,
        engineUnit: MasterValueUnit.canvasPx,
        rendererUnit: MasterValueUnit.devicePx,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: -100000,
        maxValue: 100000,
        mapper: _mapPosition,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'shadowOffsetY': const MasterPropertyDefinition(
        id: 'shadowOffsetY',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.dimension,
        uiUnit: MasterValueUnit.canvasPx,
        engineUnit: MasterValueUnit.canvasPx,
        rendererUnit: MasterValueUnit.devicePx,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: -100000,
        maxValue: 100000,
        mapper: _mapPosition,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'shadowSpread': const MasterPropertyDefinition(
        id: 'shadowSpread',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.dimension,
        uiUnit: MasterValueUnit.canvasPx,
        engineUnit: MasterValueUnit.canvasPx,
        rendererUnit: MasterValueUnit.devicePx,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: -100000,
        maxValue: 100000,
        mapper: _mapPosition,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'shadowColor': const MasterPropertyDefinition(
        id: 'shadowColor',
        category: MasterPropertyCategory.color,
        valueType: MasterValueType.color,
        uiUnit: MasterValueUnit.colorArgb,
        engineUnit: MasterValueUnit.colorArgb,
        rendererUnit: MasterValueUnit.colorArgb,
        defaultValue: MotionPropertyValue.colorArgb(0xFF000000),
        minValue: 0,
        maxValue: 4294967295,
        mapper: _mapColorArgb,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'visualColor': const MasterPropertyDefinition(
        id: 'visualColor',
        category: MasterPropertyCategory.color,
        valueType: MasterValueType.color,
        uiUnit: MasterValueUnit.colorArgb,
        engineUnit: MasterValueUnit.colorArgb,
        rendererUnit: MasterValueUnit.colorArgb,
        defaultValue: MotionPropertyValue.colorArgb(0xFFFFFFFF),
        minValue: 0,
        maxValue: 4294967295,
        mapper: _mapColorArgb,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'maskRevealProgress': const MasterPropertyDefinition(
        id: 'maskRevealProgress',
        category: MasterPropertyCategory.mask,
        valueType: MasterValueType.percent,
        uiUnit: MasterValueUnit.percentUi,
        engineUnit: MasterValueUnit.normalized01,
        rendererUnit: MasterValueUnit.normalized01,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: 0,
        maxValue: 100,
        mapper: _mapPercent01,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'trimStart': const MasterPropertyDefinition(
        id: 'trimStart',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.percent,
        uiUnit: MasterValueUnit.percentUi,
        engineUnit: MasterValueUnit.normalized01,
        rendererUnit: MasterValueUnit.normalized01,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: 0,
        maxValue: 100,
        mapper: _mapPercent01,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'trimEnd': const MasterPropertyDefinition(
        id: 'trimEnd',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.percent,
        uiUnit: MasterValueUnit.percentUi,
        engineUnit: MasterValueUnit.normalized01,
        rendererUnit: MasterValueUnit.normalized01,
        defaultValue: MotionPropertyValue.scalar(100),
        minValue: 0,
        maxValue: 100,
        mapper: _mapPercent01,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'trimOffset': const MasterPropertyDefinition(
        id: 'trimOffset',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.signedPercent,
        uiUnit: MasterValueUnit.signedPercentUi,
        engineUnit: MasterValueUnit.normalized01,
        rendererUnit: MasterValueUnit.normalized01,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: -100,
        maxValue: 100,
        mapper: _mapSignedPercent01,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'cropRect': const MasterPropertyDefinition(
        id: 'cropRect',
        category: MasterPropertyCategory.crop,
        valueType: MasterValueType.scalar,
        uiUnit: MasterValueUnit.normalized01,
        engineUnit: MasterValueUnit.normalized01,
        rendererUnit: MasterValueUnit.normalized01,
        defaultValue: MotionPropertyValue.rect(
          MotionRect(left: 0, top: 0, width: 1, height: 1),
        ),
        minValue: 0,
        maxValue: 1,
        mapper: _mapCropRect,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'shapeWidth': const MasterPropertyDefinition(
        id: 'shapeWidth',
        category: MasterPropertyCategory.shape,
        valueType: MasterValueType.dimension,
        uiUnit: MasterValueUnit.canvasPx,
        engineUnit: MasterValueUnit.canvasPx,
        rendererUnit: MasterValueUnit.devicePx,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: 0,
        maxValue: 100000,
        mapper: _mapPositiveDimension,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'shapeHeight': const MasterPropertyDefinition(
        id: 'shapeHeight',
        category: MasterPropertyCategory.shape,
        valueType: MasterValueType.dimension,
        uiUnit: MasterValueUnit.canvasPx,
        engineUnit: MasterValueUnit.canvasPx,
        rendererUnit: MasterValueUnit.devicePx,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: 0,
        maxValue: 100000,
        mapper: _mapPositiveDimension,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'shapeCornerRadius': const MasterPropertyDefinition(
        id: 'shapeCornerRadius',
        category: MasterPropertyCategory.shape,
        valueType: MasterValueType.dimension,
        uiUnit: MasterValueUnit.canvasPx,
        engineUnit: MasterValueUnit.canvasPx,
        rendererUnit: MasterValueUnit.devicePx,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: 0,
        maxValue: 100000,
        mapper: _mapPositiveDimension,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'textFontSize': const MasterPropertyDefinition(
        id: 'textFontSize',
        category: MasterPropertyCategory.text,
        valueType: MasterValueType.dimension,
        uiUnit: MasterValueUnit.canvasPx,
        engineUnit: MasterValueUnit.canvasPx,
        rendererUnit: MasterValueUnit.devicePx,
        defaultValue: MotionPropertyValue.scalar(16),
        minValue: 1,
        maxValue: 1000,
        mapper: _mapPositiveDimension,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'textFontWeight': const MasterPropertyDefinition(
        id: 'textFontWeight',
        category: MasterPropertyCategory.text,
        valueType: MasterValueType.scalar,
        uiUnit: MasterValueUnit.enumToken,
        engineUnit: MasterValueUnit.enumToken,
        rendererUnit: MasterValueUnit.enumToken,
        defaultValue: MotionPropertyValue.integer(700),
        minValue: 100,
        maxValue: 900,
        mapper: _mapScalar,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'textFontFamily': const MasterPropertyDefinition(
        id: 'textFontFamily',
        category: MasterPropertyCategory.text,
        valueType: MasterValueType.stringValue,
        uiUnit: MasterValueUnit.stringToken,
        engineUnit: MasterValueUnit.stringToken,
        rendererUnit: MasterValueUnit.stringToken,
        defaultValue: MotionPropertyValue.stringValue(''),
        minValue: 0,
        maxValue: 0,
        mapper: _mapString,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'textFontStyle': const MasterPropertyDefinition(
        id: 'textFontStyle',
        category: MasterPropertyCategory.text,
        valueType: MasterValueType.stringValue,
        uiUnit: MasterValueUnit.stringToken,
        engineUnit: MasterValueUnit.stringToken,
        rendererUnit: MasterValueUnit.stringToken,
        defaultValue: MotionPropertyValue.stringValue('normal'),
        minValue: 0,
        maxValue: 0,
        mapper: _mapString,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'textLineHeight': const MasterPropertyDefinition(
        id: 'textLineHeight',
        category: MasterPropertyCategory.text,
        valueType: MasterValueType.scalar,
        uiUnit: MasterValueUnit.multiplier,
        engineUnit: MasterValueUnit.multiplier,
        rendererUnit: MasterValueUnit.multiplier,
        defaultValue: MotionPropertyValue.scalar(1),
        minValue: 0,
        maxValue: 10,
        mapper: _mapPositiveScalar,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'textAlignment': const MasterPropertyDefinition(
        id: 'textAlignment',
        category: MasterPropertyCategory.text,
        valueType: MasterValueType.stringValue,
        uiUnit: MasterValueUnit.stringToken,
        engineUnit: MasterValueUnit.stringToken,
        rendererUnit: MasterValueUnit.stringToken,
        defaultValue: MotionPropertyValue.stringValue('center'),
        minValue: 0,
        maxValue: 0,
        mapper: _mapString,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'textLetterSpacing': const MasterPropertyDefinition(
        id: 'textLetterSpacing',
        category: MasterPropertyCategory.text,
        valueType: MasterValueType.dimension,
        uiUnit: MasterValueUnit.canvasPx,
        engineUnit: MasterValueUnit.canvasPx,
        rendererUnit: MasterValueUnit.devicePx,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: -100000,
        maxValue: 100000,
        mapper: _mapPosition,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'textRevealProgress': const MasterPropertyDefinition(
        id: 'textRevealProgress',
        category: MasterPropertyCategory.text,
        valueType: MasterValueType.percent,
        uiUnit: MasterValueUnit.percentUi,
        engineUnit: MasterValueUnit.normalized01,
        rendererUnit: MasterValueUnit.normalized01,
        defaultValue: MotionPropertyValue.scalar(100),
        minValue: 0,
        maxValue: 100,
        mapper: _mapPercent01,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'motionBlurAmount': const MasterPropertyDefinition(
        id: 'motionBlurAmount',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.percent,
        uiUnit: MasterValueUnit.percentUi,
        engineUnit: MasterValueUnit.normalized01,
        rendererUnit: MasterValueUnit.normalized01,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: 0,
        maxValue: 100,
        mapper: _mapMotionBlurAmount,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'motionBlurEnabled': const MasterPropertyDefinition(
        id: 'motionBlurEnabled',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.boolean,
        uiUnit: MasterValueUnit.enumToken,
        engineUnit: MasterValueUnit.enumToken,
        rendererUnit: MasterValueUnit.enumToken,
        defaultValue: MotionPropertyValue.boolean(false),
        minValue: 0,
        maxValue: 1,
        mapper: _mapBoolean,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'motionBlurShutterAngle': const MasterPropertyDefinition(
        id: 'motionBlurShutterAngle',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.degrees,
        uiUnit: MasterValueUnit.degrees,
        engineUnit: MasterValueUnit.degrees,
        rendererUnit: MasterValueUnit.degrees,
        defaultValue: MotionPropertyValue.scalar(180),
        minValue: 0,
        maxValue: 1440,
        mapper: _mapMotionBlurShutterAngle,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'motionBlurShutterPhase': const MasterPropertyDefinition(
        id: 'motionBlurShutterPhase',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.degrees,
        uiUnit: MasterValueUnit.degrees,
        engineUnit: MasterValueUnit.degrees,
        rendererUnit: MasterValueUnit.degrees,
        defaultValue: MotionPropertyValue.scalar(-90),
        minValue: -720,
        maxValue: 720,
        mapper: _mapMotionBlurShutterPhase,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'motionBlurSamples': const MasterPropertyDefinition(
        id: 'motionBlurSamples',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.scalar,
        uiUnit: MasterValueUnit.enumToken,
        engineUnit: MasterValueUnit.enumToken,
        rendererUnit: MasterValueUnit.enumToken,
        defaultValue: MotionPropertyValue.integer(8),
        minValue: 1,
        maxValue: 64,
        mapper: _mapMotionBlurSamples,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'motionBlurAdaptiveSampleLimit': const MasterPropertyDefinition(
        id: 'motionBlurAdaptiveSampleLimit',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.scalar,
        uiUnit: MasterValueUnit.enumToken,
        engineUnit: MasterValueUnit.enumToken,
        rendererUnit: MasterValueUnit.enumToken,
        defaultValue: MotionPropertyValue.integer(16),
        minValue: 1,
        maxValue: 128,
        mapper: _mapMotionBlurAdaptiveSampleLimit,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'motionBlurMaxTrailPx': const MasterPropertyDefinition(
        id: 'motionBlurMaxTrailPx',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.dimension,
        uiUnit: MasterValueUnit.canvasPx,
        engineUnit: MasterValueUnit.canvasPx,
        rendererUnit: MasterValueUnit.devicePx,
        defaultValue: MotionPropertyValue.scalar(240),
        minValue: 0,
        maxValue: 4096,
        mapper: _mapMotionBlurMaxTrailPx,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'motionBlurAffectPosition': const MasterPropertyDefinition(
        id: 'motionBlurAffectPosition',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.boolean,
        uiUnit: MasterValueUnit.enumToken,
        engineUnit: MasterValueUnit.enumToken,
        rendererUnit: MasterValueUnit.enumToken,
        defaultValue: MotionPropertyValue.boolean(true),
        minValue: 0,
        maxValue: 1,
        mapper: _mapBoolean,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'motionBlurAffectScale': const MasterPropertyDefinition(
        id: 'motionBlurAffectScale',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.boolean,
        uiUnit: MasterValueUnit.enumToken,
        engineUnit: MasterValueUnit.enumToken,
        rendererUnit: MasterValueUnit.enumToken,
        defaultValue: MotionPropertyValue.boolean(true),
        minValue: 0,
        maxValue: 1,
        mapper: _mapBoolean,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'motionBlurAffectRotation': const MasterPropertyDefinition(
        id: 'motionBlurAffectRotation',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.boolean,
        uiUnit: MasterValueUnit.enumToken,
        engineUnit: MasterValueUnit.enumToken,
        rendererUnit: MasterValueUnit.enumToken,
        defaultValue: MotionPropertyValue.boolean(true),
        minValue: 0,
        maxValue: 1,
        mapper: _mapBoolean,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'edgeFillEnabled': const MasterPropertyDefinition(
        id: 'edgeFillEnabled',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.boolean,
        uiUnit: MasterValueUnit.enumToken,
        engineUnit: MasterValueUnit.enumToken,
        rendererUnit: MasterValueUnit.enumToken,
        defaultValue: MotionPropertyValue.boolean(true),
        minValue: 0,
        maxValue: 1,
        mapper: _mapBoolean,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'edgeFillAmount': const MasterPropertyDefinition(
        id: 'edgeFillAmount',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.percent,
        uiUnit: MasterValueUnit.percentUi,
        engineUnit: MasterValueUnit.normalized01,
        rendererUnit: MasterValueUnit.normalized01,
        defaultValue: MotionPropertyValue.scalar(100),
        minValue: 0,
        maxValue: 100,
        mapper: _mapPercent01,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'edgeFillMode': const MasterPropertyDefinition(
        id: 'edgeFillMode',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.scalar,
        uiUnit: MasterValueUnit.enumToken,
        engineUnit: MasterValueUnit.enumToken,
        rendererUnit: MasterValueUnit.enumToken,
        defaultValue: MotionPropertyValue.integer(1),
        minValue: 0,
        maxValue: 7,
        mapper: _mapScalar,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'edgeFillOverscanScale': const MasterPropertyDefinition(
        id: 'edgeFillOverscanScale',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.scalar,
        uiUnit: MasterValueUnit.multiplier,
        engineUnit: MasterValueUnit.multiplier,
        rendererUnit: MasterValueUnit.multiplier,
        defaultValue: MotionPropertyValue.scalar(1),
        minValue: 1,
        maxValue: 10,
        mapper: _mapPositiveScalar,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'edgeFillSoftnessPx': const MasterPropertyDefinition(
        id: 'edgeFillSoftnessPx',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.dimension,
        uiUnit: MasterValueUnit.canvasPx,
        engineUnit: MasterValueUnit.canvasPx,
        rendererUnit: MasterValueUnit.devicePx,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: 0,
        maxValue: 512,
        mapper: _mapPositiveDimension,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'edgeFillBlurSigmaPx': const MasterPropertyDefinition(
        id: 'edgeFillBlurSigmaPx',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.dimension,
        uiUnit: MasterValueUnit.canvasPx,
        engineUnit: MasterValueUnit.canvasPx,
        rendererUnit: MasterValueUnit.devicePx,
        defaultValue: MotionPropertyValue.scalar(0),
        minValue: 0,
        maxValue: 512,
        mapper: _mapPositiveDimension,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'edgeFillMaxExpansionPx': const MasterPropertyDefinition(
        id: 'edgeFillMaxExpansionPx',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.dimension,
        uiUnit: MasterValueUnit.canvasPx,
        engineUnit: MasterValueUnit.canvasPx,
        rendererUnit: MasterValueUnit.devicePx,
        defaultValue: MotionPropertyValue.scalar(320),
        minValue: 0,
        maxValue: 8192,
        mapper: _mapPositiveDimension,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'edgeFillAffectRotation': const MasterPropertyDefinition(
        id: 'edgeFillAffectRotation',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.boolean,
        uiUnit: MasterValueUnit.enumToken,
        engineUnit: MasterValueUnit.enumToken,
        rendererUnit: MasterValueUnit.enumToken,
        defaultValue: MotionPropertyValue.boolean(true),
        minValue: 0,
        maxValue: 1,
        mapper: _mapBoolean,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'edgeFillAffectScale': const MasterPropertyDefinition(
        id: 'edgeFillAffectScale',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.boolean,
        uiUnit: MasterValueUnit.enumToken,
        engineUnit: MasterValueUnit.enumToken,
        rendererUnit: MasterValueUnit.enumToken,
        defaultValue: MotionPropertyValue.boolean(true),
        minValue: 0,
        maxValue: 1,
        mapper: _mapBoolean,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'edgeFillAffectPosition': const MasterPropertyDefinition(
        id: 'edgeFillAffectPosition',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.boolean,
        uiUnit: MasterValueUnit.enumToken,
        engineUnit: MasterValueUnit.enumToken,
        rendererUnit: MasterValueUnit.enumToken,
        defaultValue: MotionPropertyValue.boolean(true),
        minValue: 0,
        maxValue: 1,
        mapper: _mapBoolean,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'edgeFillAffectMotionBlur': const MasterPropertyDefinition(
        id: 'edgeFillAffectMotionBlur',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.boolean,
        uiUnit: MasterValueUnit.enumToken,
        engineUnit: MasterValueUnit.enumToken,
        rendererUnit: MasterValueUnit.enumToken,
        defaultValue: MotionPropertyValue.boolean(true),
        minValue: 0,
        maxValue: 1,
        mapper: _mapBoolean,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
      'tileOutputScale': const MasterPropertyDefinition(
        id: 'tileOutputScale',
        category: MasterPropertyCategory.effect,
        valueType: MasterValueType.scalar,
        uiUnit: MasterValueUnit.multiplier,
        engineUnit: MasterValueUnit.multiplier,
        rendererUnit: MasterValueUnit.multiplier,
        defaultValue: MotionPropertyValue.scalar(1),
        minValue: 0.1,
        maxValue: 10,
        mapper: _mapTileOutputScale,
        supportedTargets: <MotionTargetKind>[
          MotionTargetKind.layer,
          MotionTargetKind.element,
        ],
        supportedRenderModes: <MasterRenderCapability>[
          MasterRenderCapability.preview,
          MasterRenderCapability.playback,
          MasterRenderCapability.liveScrub,
          MasterRenderCapability.export,
        ],
      ),
    };
  }

  static MasterPropertyValueMapping _mapOpacity(MotionPropertyValue value) {
    final raw = _readScalar(value, fallback: 1);
    final uiPercent = raw <= 1.0 ? (raw * 100.0) : raw;
    final clampedUi = uiPercent.clamp(0.0, 100.0).toDouble();
    final normalized = (clampedUi / 100.0).clamp(0.0, 1.0).toDouble();
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: clampedUi),
      engine: MasterValueLayer(scalar: normalized),
      renderer: MasterValueLayer(scalar: normalized),
      uiUnit: MasterValueUnit.percentUi,
      engineUnit: MasterValueUnit.normalized01,
      rendererUnit: MasterValueUnit.normalized01,
    );
  }

  static MasterPropertyValueMapping _mapScale(MotionPropertyValue value) {
    final raw = _readScalar(value, fallback: 1);
    final multiplier =
        raw >= 0.01 && raw <= 16.0 ? raw : math.max(0.01, 1.0 + (raw / 100.0));
    final uiPercent = (multiplier - 1.0) * 100.0;
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: uiPercent),
      engine: MasterValueLayer(scalar: multiplier),
      renderer: MasterValueLayer(scalar: multiplier),
      uiUnit: MasterValueUnit.signedPercentUi,
      engineUnit: MasterValueUnit.multiplier,
      rendererUnit: MasterValueUnit.multiplier,
    );
  }

  static MasterPropertyValueMapping _mapPosition(MotionPropertyValue value) {
    final uiPx = _readScalar(value, fallback: 0);
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: uiPx),
      engine: MasterValueLayer(scalar: uiPx),
      renderer: MasterValueLayer(scalar: uiPx),
      uiUnit: MasterValueUnit.canvasPx,
      engineUnit: MasterValueUnit.canvasPx,
      rendererUnit: MasterValueUnit.devicePx,
    );
  }

  static MasterPropertyValueMapping _mapRotation(MotionPropertyValue value) {
    final degrees = _readScalar(value, fallback: 0);
    final radians = degrees * (math.pi / 180.0);
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: degrees),
      engine: MasterValueLayer(scalar: degrees),
      renderer: MasterValueLayer(scalar: radians),
      uiUnit: MasterValueUnit.degrees,
      engineUnit: MasterValueUnit.degrees,
      rendererUnit: MasterValueUnit.radians,
    );
  }

  static MasterPropertyValueMapping _mapGaussianBlur(
      MotionPropertyValue value) {
    final pixels = math.max(0.0, _readScalar(value, fallback: 0));
    final sigma = pixels <= 0 ? 0.0 : (pixels * 0.57735);
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: pixels),
      engine: MasterValueLayer(scalar: pixels),
      renderer: MasterValueLayer(scalar: sigma),
      uiUnit: MasterValueUnit.canvasPx,
      engineUnit: MasterValueUnit.canvasPx,
      rendererUnit: MasterValueUnit.shaderSigmaPx,
    );
  }

  static MasterPropertyValueMapping _mapMotionBlurAmount(
    MotionPropertyValue value,
  ) {
    final raw = _readScalar(value, fallback: 0);
    final percent = raw <= 1.0 ? raw * 100.0 : raw;
    final clampedPercent = percent.clamp(0.0, 100.0).toDouble();
    final normalized = (clampedPercent / 100.0).clamp(0.0, 1.0).toDouble();
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: clampedPercent),
      engine: MasterValueLayer(scalar: normalized),
      renderer: MasterValueLayer(scalar: normalized),
      uiUnit: MasterValueUnit.percentUi,
      engineUnit: MasterValueUnit.normalized01,
      rendererUnit: MasterValueUnit.normalized01,
    );
  }

  static MasterPropertyValueMapping _mapMotionBlurShutterAngle(
    MotionPropertyValue value,
  ) {
    final degrees =
        _readScalar(value, fallback: 180).clamp(0.0, 1440.0).toDouble();
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: degrees),
      engine: MasterValueLayer(scalar: degrees),
      renderer: MasterValueLayer(scalar: degrees),
      uiUnit: MasterValueUnit.degrees,
      engineUnit: MasterValueUnit.degrees,
      rendererUnit: MasterValueUnit.degrees,
    );
  }

  static MasterPropertyValueMapping _mapMotionBlurShutterPhase(
    MotionPropertyValue value,
  ) {
    final degrees =
        _readScalar(value, fallback: -90).clamp(-720.0, 720.0).toDouble();
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: degrees),
      engine: MasterValueLayer(scalar: degrees),
      renderer: MasterValueLayer(scalar: degrees),
      uiUnit: MasterValueUnit.degrees,
      engineUnit: MasterValueUnit.degrees,
      rendererUnit: MasterValueUnit.degrees,
    );
  }

  static MasterPropertyValueMapping _mapMotionBlurSamples(
    MotionPropertyValue value,
  ) {
    final samples =
        _readScalar(value, fallback: 8).round().clamp(1, 64).toDouble();
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: samples),
      engine: MasterValueLayer(scalar: samples),
      renderer: MasterValueLayer(scalar: samples),
      uiUnit: MasterValueUnit.enumToken,
      engineUnit: MasterValueUnit.enumToken,
      rendererUnit: MasterValueUnit.enumToken,
    );
  }

  static MasterPropertyValueMapping _mapMotionBlurAdaptiveSampleLimit(
    MotionPropertyValue value,
  ) {
    final samples =
        _readScalar(value, fallback: 16).round().clamp(1, 128).toDouble();
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: samples),
      engine: MasterValueLayer(scalar: samples),
      renderer: MasterValueLayer(scalar: samples),
      uiUnit: MasterValueUnit.enumToken,
      engineUnit: MasterValueUnit.enumToken,
      rendererUnit: MasterValueUnit.enumToken,
    );
  }

  static MasterPropertyValueMapping _mapMotionBlurMaxTrailPx(
    MotionPropertyValue value,
  ) {
    final pixels =
        _readScalar(value, fallback: 240).clamp(0.0, 4096.0).toDouble();
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: pixels),
      engine: MasterValueLayer(scalar: pixels),
      renderer: MasterValueLayer(scalar: pixels),
      uiUnit: MasterValueUnit.canvasPx,
      engineUnit: MasterValueUnit.canvasPx,
      rendererUnit: MasterValueUnit.devicePx,
    );
  }

  static MasterPropertyValueMapping _mapTileOutputScale(
    MotionPropertyValue value,
  ) {
    final multiplier = math.max(0.1, _readScalar(value, fallback: 1));
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: multiplier),
      engine: MasterValueLayer(scalar: multiplier),
      renderer: MasterValueLayer(scalar: multiplier),
      uiUnit: MasterValueUnit.multiplier,
      engineUnit: MasterValueUnit.multiplier,
      rendererUnit: MasterValueUnit.multiplier,
    );
  }

  static MasterPropertyValueMapping _mapBoolean(MotionPropertyValue value) {
    final enabled = _readBoolean(value, fallback: false);
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(booleanValue: enabled),
      engine: MasterValueLayer(booleanValue: enabled),
      renderer: MasterValueLayer(booleanValue: enabled),
      uiUnit: MasterValueUnit.enumToken,
      engineUnit: MasterValueUnit.enumToken,
      rendererUnit: MasterValueUnit.enumToken,
    );
  }

  static MasterPropertyValueMapping _mapPercent01(MotionPropertyValue value) {
    final raw = _readScalar(value, fallback: 0);
    final percent = raw <= 1.0 ? raw * 100.0 : raw;
    final clampedPercent = percent.clamp(0.0, 100.0).toDouble();
    final normalized = (clampedPercent / 100.0).clamp(0.0, 1.0).toDouble();
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: clampedPercent),
      engine: MasterValueLayer(scalar: normalized),
      renderer: MasterValueLayer(scalar: normalized),
      uiUnit: MasterValueUnit.percentUi,
      engineUnit: MasterValueUnit.normalized01,
      rendererUnit: MasterValueUnit.normalized01,
    );
  }

  static MasterPropertyValueMapping _mapSignedPercent01(
    MotionPropertyValue value,
  ) {
    final raw = _readScalar(value, fallback: 0);
    final percent = raw.abs() <= 1.0 ? raw * 100.0 : raw;
    final clampedPercent = percent.clamp(-100.0, 100.0).toDouble();
    final normalized = (clampedPercent / 100.0).clamp(-1.0, 1.0).toDouble();
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: clampedPercent),
      engine: MasterValueLayer(scalar: normalized),
      renderer: MasterValueLayer(scalar: normalized),
      uiUnit: MasterValueUnit.signedPercentUi,
      engineUnit: MasterValueUnit.normalized01,
      rendererUnit: MasterValueUnit.normalized01,
    );
  }

  static MasterPropertyValueMapping _mapScalar(MotionPropertyValue value) {
    final scalar = _readScalar(value, fallback: 0);
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: scalar),
      engine: MasterValueLayer(scalar: scalar),
      renderer: MasterValueLayer(scalar: scalar),
      uiUnit: MasterValueUnit.enumToken,
      engineUnit: MasterValueUnit.enumToken,
      rendererUnit: MasterValueUnit.enumToken,
    );
  }

  static MasterPropertyValueMapping _mapPositiveScalar(
    MotionPropertyValue value,
  ) {
    final scalar = math.max(0.0, _readScalar(value, fallback: 0));
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: scalar),
      engine: MasterValueLayer(scalar: scalar),
      renderer: MasterValueLayer(scalar: scalar),
      uiUnit: MasterValueUnit.multiplier,
      engineUnit: MasterValueUnit.multiplier,
      rendererUnit: MasterValueUnit.multiplier,
    );
  }

  static MasterPropertyValueMapping _mapPositiveDimension(
    MotionPropertyValue value,
  ) {
    final pixels = math.max(0.0, _readScalar(value, fallback: 0));
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: pixels),
      engine: MasterValueLayer(scalar: pixels),
      renderer: MasterValueLayer(scalar: pixels),
      uiUnit: MasterValueUnit.canvasPx,
      engineUnit: MasterValueUnit.canvasPx,
      rendererUnit: MasterValueUnit.devicePx,
    );
  }

  static MasterPropertyValueMapping _mapString(MotionPropertyValue value) {
    final token =
        value.kind == MotionPropertyValueKind.stringValue ? value.rawValue : '';
    final stringValue = token is String ? token : '';
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(token: stringValue),
      engine: MasterValueLayer(token: stringValue),
      renderer: MasterValueLayer(token: stringValue),
      uiUnit: MasterValueUnit.stringToken,
      engineUnit: MasterValueUnit.stringToken,
      rendererUnit: MasterValueUnit.stringToken,
    );
  }

  static MasterPropertyValueMapping _mapCropRect(MotionPropertyValue value) {
    final rect = value.kind == MotionPropertyValueKind.rect &&
            value.rawValue is MotionRect
        ? value.rawValue as MotionRect
        : const MotionRect(left: 0, top: 0, width: 1, height: 1);
    final normalized = MotionRect(
      left: rect.left.clamp(0.0, 1.0).toDouble(),
      top: rect.top.clamp(0.0, 1.0).toDouble(),
      width: rect.width.clamp(0.0, 1.0).toDouble(),
      height: rect.height.clamp(0.0, 1.0).toDouble(),
    );
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(rect: normalized),
      engine: MasterValueLayer(rect: normalized),
      renderer: MasterValueLayer(rect: normalized),
      uiUnit: MasterValueUnit.normalized01,
      engineUnit: MasterValueUnit.normalized01,
      rendererUnit: MasterValueUnit.normalized01,
    );
  }

  static MasterPropertyValueMapping _mapColorArgb(MotionPropertyValue value) {
    final color =
        value.kind == MotionPropertyValueKind.colorArgb && value.rawValue is int
            ? (value.rawValue as int)
            : 0xFF000000;
    return MasterPropertyValueMapping(
      ui: MasterValueLayer(colorArgb: color),
      engine: MasterValueLayer(colorArgb: color),
      renderer: MasterValueLayer(colorArgb: color),
      uiUnit: MasterValueUnit.colorArgb,
      engineUnit: MasterValueUnit.colorArgb,
      rendererUnit: MasterValueUnit.colorArgb,
    );
  }

  static double _readScalar(MotionPropertyValue value,
      {required double fallback}) {
    if (value.kind != MotionPropertyValueKind.scalar &&
        value.kind != MotionPropertyValueKind.integer) {
      return fallback;
    }
    final raw = value.rawValue;
    if (raw is! num || !raw.toDouble().isFinite) {
      return fallback;
    }
    return raw.toDouble();
  }

  static bool _readBoolean(MotionPropertyValue value,
      {required bool fallback}) {
    if (value.kind == MotionPropertyValueKind.boolean) {
      final raw = value.rawValue;
      return raw is bool ? raw : fallback;
    }
    if (value.kind == MotionPropertyValueKind.scalar ||
        value.kind == MotionPropertyValueKind.integer) {
      final raw = value.rawValue;
      if (raw is num) {
        return raw != 0;
      }
    }
    return fallback;
  }
}
