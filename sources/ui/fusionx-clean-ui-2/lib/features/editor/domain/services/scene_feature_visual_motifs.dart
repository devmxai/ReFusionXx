class SceneFeatureVisualMotifSpec {
  const SceneFeatureVisualMotifSpec({
    required this.id,
    required this.iconToken,
    required this.recipeId,
    required this.opacity,
  });

  final String id;
  final String iconToken;
  final String recipeId;
  final double opacity;
}

class SceneFeatureVisualMotifs {
  const SceneFeatureVisualMotifs();

  SceneFeatureVisualMotifSpec resolve({
    required String label,
    required String body,
  }) {
    final normalized = _normalize('$label $body');
    if (_hasAny(
        normalized, const <String>['voice', 'audio', 'dubb', 'music'])) {
      return const SceneFeatureVisualMotifSpec(
        id: 'motif.audio',
        iconToken: r'$icon.audioEngineering',
        recipeId: r'$motion.iconPulse',
        opacity: 0.24,
      );
    }
    if (_hasAny(normalized, const <String>['caption', 'subtitle', 'text'])) {
      return const SceneFeatureVisualMotifSpec(
        id: 'motif.captions',
        iconToken: r'$icon.captions',
        recipeId: r'$motion.iconPulse',
        opacity: 0.22,
      );
    }
    if (_hasAny(normalized, const <String>['montage', 'edit', 'timeline'])) {
      return const SceneFeatureVisualMotifSpec(
        id: 'motif.montage',
        iconToken: r'$icon.montage',
        recipeId: r'$motion.iconPulse',
        opacity: 0.24,
      );
    }
    if (_hasAny(normalized, const <String>['retouch', 'image', 'photo'])) {
      return const SceneFeatureVisualMotifSpec(
        id: 'motif.image',
        iconToken: r'$icon.imageRetouch',
        recipeId: r'$motion.iconPulse',
        opacity: 0.2,
      );
    }
    if (_hasAny(normalized, const <String>['color', 'grade', 'lut'])) {
      return const SceneFeatureVisualMotifSpec(
        id: 'motif.color',
        iconToken: r'$icon.colorGrade',
        recipeId: r'$motion.iconPulse',
        opacity: 0.2,
      );
    }
    return const SceneFeatureVisualMotifSpec(
      id: 'motif.default',
      iconToken: r'$icon.appBuild',
      recipeId: r'$motion.iconPulse',
      opacity: 0.18,
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
