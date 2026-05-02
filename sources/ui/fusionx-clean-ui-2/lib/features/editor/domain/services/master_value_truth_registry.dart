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

  static double _readScalar(MotionPropertyValue value,
      {required double fallback}) {
    if (value.kind != MotionPropertyValueKind.scalar) {
      return fallback;
    }
    final raw = value.rawValue;
    if (raw is! double || !raw.isFinite) {
      return fallback;
    }
    return raw;
  }
}
