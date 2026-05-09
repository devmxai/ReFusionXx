import '../models/refusion_motion_director_models.dart';
import '../models/scene_director_brief_models.dart';
import 'scene_micro_scene_registry.dart';

const String kSceneBackgroundPairingProofTag =
    'TF_SCENE_BACKGROUND_PAIRING_PROOF';

class SceneBackgroundPairingSpec {
  const SceneBackgroundPairingSpec({
    required this.topic,
    required this.backgroundColor,
    required this.microSceneId,
    required this.accentColor,
  });

  final String topic;
  final String backgroundColor;
  final String microSceneId;
  final String accentColor;
}

class SceneBackgroundPairingResult {
  const SceneBackgroundPairingResult({
    required this.spec,
    required this.microScene,
    required this.issues,
  });

  final SceneBackgroundPairingSpec spec;
  final SceneMicroSceneSpec? microScene;
  final List<ReFusionMotionDirectorIssue> issues;
}

class SceneBackgroundSemanticPairing {
  const SceneBackgroundSemanticPairing({
    SceneMicroSceneRegistry microSceneRegistry =
        const SceneMicroSceneRegistry(),
  }) : _microSceneRegistry = microSceneRegistry;

  final SceneMicroSceneRegistry _microSceneRegistry;

  SceneBackgroundPairingResult resolve(SceneDirectorBrief brief) {
    final joined = _normalize(
      '${brief.intent} ${brief.mood} ${brief.primaryFocus} '
      '${brief.elements.map((entry) => entry.kind).join(' ')} '
      '${brief.elements.expand((entry) => entry.cards).map((card) => '${card.label} ${card.body}').join(' ')}',
    );
    SceneBackgroundPairingSpec spec;
    if (_hasAny(joined, const <String>['voice', 'audio', 'dubb', 'music'])) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'audio',
        backgroundColor: '#0F1520',
        microSceneId: 'audio.waveform',
        accentColor: '#7C9BFF',
      );
    } else if (_hasAny(joined, const <String>['caption', 'subtitle', 'text'])) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'captions',
        backgroundColor: '#101623',
        microSceneId: 'captions.lines',
        accentColor: '#95A9FF',
      );
    } else if (_hasAny(joined, const <String>['montage', 'edit', 'timeline'])) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'montage',
        backgroundColor: '#111826',
        microSceneId: 'montage.timeline',
        accentColor: '#7A93FF',
      );
    } else if (_hasAny(joined, const <String>['retouch', 'image', 'photo'])) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'image',
        backgroundColor: '#111825',
        microSceneId: 'image.sparkles',
        accentColor: '#86D0FF',
      );
    } else if (_hasAny(joined, const <String>['color', 'grade', 'lut'])) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'color',
        backgroundColor: '#121726',
        microSceneId: 'color.wheels',
        accentColor: '#7AC0FF',
      );
    } else if (_hasAny(
        joined, const <String>['app', 'build', 'module', 'code'])) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'app',
        backgroundColor: '#0F1622',
        microSceneId: 'app.modules',
        accentColor: '#8BA6FF',
      );
    } else {
      spec = const SceneBackgroundPairingSpec(
        topic: 'default',
        backgroundColor: '#10141E',
        microSceneId: 'app.modules',
        accentColor: '#7B8FB7',
      );
    }

    final microScene = _microSceneRegistry.find(spec.microSceneId);
    final issues = <ReFusionMotionDirectorIssue>[
      ReFusionMotionDirectorIssue(
        severity: ReFusionMotionDirectorIssueSeverity.info,
        message: '$kSceneBackgroundPairingProofTag '
            'topic=${spec.topic} '
            'microSceneId=${spec.microSceneId} '
            'resolved=${(microScene != null).toString()} '
            'fallbackReason=${microScene == null ? 'missing_micro_scene' : 'none'}',
        path: 'backgroundPairing',
      ),
    ];
    return SceneBackgroundPairingResult(
      spec: spec,
      microScene: microScene,
      issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
    );
  }

  bool _hasAny(String source, List<String> tokens) {
    for (final token in tokens) {
      if (source.contains(_normalize(token))) {
        return true;
      }
    }
    return false;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
