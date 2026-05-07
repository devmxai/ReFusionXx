import '../models/professional_motion_animation_models.dart';

class ProfessionalSpeedGraphPreset {
  const ProfessionalSpeedGraphPreset({
    required this.id,
    required this.displayName,
    required this.arabicDisplayName,
    required this.aliases,
    required this.description,
    required this.bezier,
    required this.allowsOvershoot,
    required this.thumbnailSampleCount,
    this.linear = false,
  });

  final String id;
  final String displayName;
  final String arabicDisplayName;
  final List<String> aliases;
  final String description;
  final MotionBezierControlPoints bezier;
  final bool allowsOvershoot;
  final int thumbnailSampleCount;
  final bool linear;
}

class ProfessionalSpeedGraphPresetCatalog {
  const ProfessionalSpeedGraphPresetCatalog();

  static const MotionBezierControlPoints _linearBezier =
      MotionBezierControlPoints(
    x1: 0.0,
    y1: 0.0,
    x2: 1.0,
    y2: 1.0,
  );

  static const List<ProfessionalSpeedGraphPreset> presets =
      <ProfessionalSpeedGraphPreset>[
    ProfessionalSpeedGraphPreset(
      id: 'linear',
      displayName: 'Linear',
      arabicDisplayName: 'خطي',
      aliases: <String>['linear'],
      description: 'Constant speed across the segment.',
      bezier: _linearBezier,
      allowsOvershoot: false,
      thumbnailSampleCount: 24,
      linear: true,
    ),
    ProfessionalSpeedGraphPreset(
      id: 'easyEase',
      displayName: 'Easy Ease',
      arabicDisplayName: 'إيزي إيز',
      aliases: <String>['easyEase', 'f9', 'cinematicEase'],
      description: 'Balanced slow start and slow finish.',
      bezier: MotionBezierControlPoints(
        x1: 0.3333,
        y1: 0.0,
        x2: 0.6667,
        y2: 1.0,
      ),
      allowsOvershoot: false,
      thumbnailSampleCount: 40,
    ),
    ProfessionalSpeedGraphPreset(
      id: 'easyEaseIn',
      displayName: 'Ease In',
      arabicDisplayName: 'بطيء ثم سريع',
      aliases: <String>['easyEaseIn', 'easeIn', 'smoothStart'],
      description: 'Slow start and fast finish.',
      bezier: MotionBezierControlPoints(
        x1: 0.65,
        y1: 0.0,
        x2: 0.95,
        y2: 0.1,
      ),
      allowsOvershoot: false,
      thumbnailSampleCount: 36,
    ),
    ProfessionalSpeedGraphPreset(
      id: 'easyEaseOut',
      displayName: 'Ease Out',
      arabicDisplayName: 'سريع ثم بطيء',
      aliases: <String>['easyEaseOut', 'easeOut', 'smoothStop'],
      description: 'Fast start and soft finish.',
      bezier: MotionBezierControlPoints(
        x1: 0.05,
        y1: 0.9,
        x2: 0.35,
        y2: 1.0,
      ),
      allowsOvershoot: false,
      thumbnailSampleCount: 36,
    ),
    ProfessionalSpeedGraphPreset(
      id: 'slowFastSlow',
      displayName: 'Slow-Fast-Slow',
      arabicDisplayName: 'بطيء-سريع-بطيء',
      aliases: <String>['slowFastSlow', 'cinematic', 'dramaticEase'],
      description: 'Stronger cinematic acceleration in the middle.',
      bezier: MotionBezierControlPoints(
        x1: 0.2,
        y1: 0.0,
        x2: 0.8,
        y2: 1.0,
      ),
      allowsOvershoot: false,
      thumbnailSampleCount: 48,
    ),
    ProfessionalSpeedGraphPreset(
      id: 'fastSlowFast',
      displayName: 'Fast-Slow-Fast',
      arabicDisplayName: 'سريع-بطيء-سريع',
      aliases: <String>['fastSlowFast', 'plateau', 'holdMiddle'],
      description: 'Fast movement with softer middle plateau.',
      bezier: MotionBezierControlPoints(
        x1: 0.12,
        y1: 0.72,
        x2: 0.88,
        y2: 0.28,
      ),
      allowsOvershoot: false,
      thumbnailSampleCount: 48,
    ),
    ProfessionalSpeedGraphPreset(
      id: 'slowFast',
      displayName: 'Slow-Fast',
      arabicDisplayName: 'بطيء-سريع',
      aliases: <String>['slowFast', 'accelerate', 'whipOut'],
      description: 'Slow build then aggressive acceleration.',
      bezier: MotionBezierControlPoints(
        x1: 0.65,
        y1: 0.0,
        x2: 0.95,
        y2: 0.1,
      ),
      allowsOvershoot: false,
      thumbnailSampleCount: 40,
    ),
    ProfessionalSpeedGraphPreset(
      id: 'fastSlow',
      displayName: 'Fast-Slow',
      arabicDisplayName: 'سريع-بطيء',
      aliases: <String>['fastSlow', 'decelerate', 'softLanding'],
      description: 'Strong start and controlled landing.',
      bezier: MotionBezierControlPoints(
        x1: 0.05,
        y1: 0.9,
        x2: 0.35,
        y2: 1.0,
      ),
      allowsOvershoot: false,
      thumbnailSampleCount: 40,
    ),
    ProfessionalSpeedGraphPreset(
      id: 'whipSnap',
      displayName: 'Whip',
      arabicDisplayName: 'ويب / سناب',
      aliases: <String>['whip', 'whipSnap', 'snap'],
      description: 'Aggressive snap motion for impactful transitions.',
      bezier: MotionBezierControlPoints(
        x1: 0.05,
        y1: 0.0,
        x2: 0.25,
        y2: 1.0,
      ),
      allowsOvershoot: false,
      thumbnailSampleCount: 44,
    ),
    ProfessionalSpeedGraphPreset(
      id: 'customSpeedGraph',
      displayName: 'Custom',
      arabicDisplayName: 'منحنى مخصص',
      aliases: <String>['custom', 'speedGraph', 'velocityGraph'],
      description: 'Custom curve edited directly from graph handles.',
      bezier: MotionBezierControlPoints(
        x1: 0.3333,
        y1: 0.0,
        x2: 0.6667,
        y2: 1.0,
      ),
      allowsOvershoot: true,
      thumbnailSampleCount: 32,
    ),
  ];

  ProfessionalSpeedGraphPreset? findById(String? id) {
    if (id == null || id.trim().isEmpty) {
      return null;
    }
    final normalized = _normalize(id);
    for (final preset in presets) {
      if (_normalize(preset.id) == normalized) {
        return preset;
      }
    }
    return null;
  }

  ProfessionalSpeedGraphPreset? findByAlias(String? alias) {
    if (alias == null || alias.trim().isEmpty) {
      return null;
    }
    final normalized = _normalize(alias);
    for (final preset in presets) {
      if (_normalize(preset.id) == normalized) {
        return preset;
      }
      for (final token in preset.aliases) {
        if (_normalize(token) == normalized) {
          return preset;
        }
      }
    }
    return null;
  }

  String canonicalId(String? raw) {
    return findByAlias(raw)?.id ?? 'linear';
  }

  static String _normalize(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
