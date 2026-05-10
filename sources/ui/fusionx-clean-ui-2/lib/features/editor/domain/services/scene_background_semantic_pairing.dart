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
    this.backgroundEnabled = true,
  });

  final String topic;
  final String backgroundColor;
  final String microSceneId;
  final String accentColor;
  final bool backgroundEnabled;
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
    final disableBackground =
        _readNoBackgroundFlag(brief.metadata) || _isNoBackgroundStyle(brief);
    final sourceText = '${brief.intent} ${brief.mood} ${brief.primaryFocus} '
        '${brief.brandContext ?? ''} ${brief.visualStyle ?? ''} '
        '${brief.elements.map((entry) => entry.kind).join(' ')} '
        '${brief.elements.expand((entry) => entry.cards).map((card) => '${card.label} ${card.body}').join(' ')}';
    final lexicon = _lexicon(sourceText);
    SceneBackgroundPairingSpec spec;
    if (disableBackground) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'disabled',
        backgroundColor: '#10141E',
        microSceneId: '',
        accentColor: '#7B8FB7',
        backgroundEnabled: false,
      );
    } else if (_hasAny(
      lexicon,
      const <String>['voice', 'audio', 'dubb', 'music', 'sound'],
    )) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'audio',
        backgroundColor: '#0F1520',
        microSceneId: 'audio.waveform',
        accentColor: '#7C9BFF',
      );
    } else if (_hasAny(
      lexicon,
      const <String>[
        'ai',
        'chatgpt',
        'claude',
        'gemini',
        'assistant',
        'prompt'
      ],
    )) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'ai',
        backgroundColor: '#0F1622',
        microSceneId: 'ai.nodes',
        accentColor: '#8BA6FF',
      );
    } else if (_hasAny(
      lexicon,
      const <String>['caption', 'subtitle', 'text'],
    )) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'captions',
        backgroundColor: '#101623',
        microSceneId: 'captions.lines',
        accentColor: '#95A9FF',
      );
    } else if (_hasAny(
      lexicon,
      const <String>['montage', 'edit', 'timeline'],
    )) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'montage',
        backgroundColor: '#111826',
        microSceneId: 'montage.timeline',
        accentColor: '#7A93FF',
      );
    } else if (_hasAny(
      lexicon,
      const <String>['retouch', 'image', 'photo'],
    )) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'image',
        backgroundColor: '#111825',
        microSceneId: 'image.sparkles',
        accentColor: '#86D0FF',
      );
    } else if (_hasAny(
      lexicon,
      const <String>['color', 'grade', 'lut'],
    )) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'color',
        backgroundColor: '#121726',
        microSceneId: 'color.wheels',
        accentColor: '#7AC0FF',
      );
    } else if (_hasAny(
      lexicon,
      const <String>['speed', 'performance', 'fast', 'latency', 'quick'],
    )) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'speed',
        backgroundColor: '#101726',
        microSceneId: 'speed.lines',
        accentColor: '#82B4FF',
      );
    } else if (_hasAny(
      lexicon,
      const <String>['cloud', 'sync', 'storage', 'drive', 'backup'],
    )) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'cloud',
        backgroundColor: '#101A27',
        microSceneId: 'cloud.paths',
        accentColor: '#8ED1FF',
      );
    } else if (_hasAny(
      lexicon,
      const <String>['social', 'community', 'feed'],
    )) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'social',
        backgroundColor: '#101826',
        microSceneId: 'social.links',
        accentColor: '#99B6FF',
      );
    } else if (_hasAny(
      lexicon,
      const <String>['privacy', 'secure', 'security', 'shield', 'lock'],
    )) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'privacy',
        backgroundColor: '#101725',
        microSceneId: 'privacy.shields',
        accentColor: '#90B6FF',
      );
    } else if (_hasAny(
      lexicon,
      const <String>['code', 'builder', 'developer', 'sdk', 'api'],
    )) {
      spec = const SceneBackgroundPairingSpec(
        topic: 'code',
        backgroundColor: '#0F1622',
        microSceneId: 'code.grid',
        accentColor: '#8BA6FF',
      );
    } else if (_hasAny(
        lexicon, const <String>['app', 'build', 'module', 'code'])) {
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

    final microScene = spec.backgroundEnabled
        ? _microSceneRegistry.find(spec.microSceneId)
        : null;
    final issues = <ReFusionMotionDirectorIssue>[
      ReFusionMotionDirectorIssue(
        severity: ReFusionMotionDirectorIssueSeverity.info,
        message: '$kSceneBackgroundPairingProofTag '
            'topic=${spec.topic} '
            'microSceneId=${spec.microSceneId} '
            'backgroundEnabled=${spec.backgroundEnabled} '
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

  bool _hasAny(Set<String> lexicon, List<String> tokens) {
    for (final token in tokens) {
      if (lexicon.contains(_normalize(token))) {
        return true;
      }
    }
    return false;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  Set<String> _lexicon(String sourceText) {
    return sourceText
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
  }

  bool _readNoBackgroundFlag(Map<String, Object?> metadata) {
    final value = metadata['noBackground'];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = _normalize(value);
      return normalized == 'true' || normalized == 'yes' || normalized == 'on';
    }
    return false;
  }

  bool _isNoBackgroundStyle(SceneDirectorBrief brief) {
    final visual = _normalize(brief.visualStyle ?? '');
    if (visual.isEmpty) {
      return false;
    }
    return visual.contains('nobackground') ||
        visual.contains('minimalplain') ||
        visual.contains('cleanplain');
  }
}
