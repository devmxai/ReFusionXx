import '../models/refusion_scene_program_models.dart';

class SceneOpticalRect {
  const SceneOpticalRect({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
  });

  final double centerX;
  final double centerY;
  final double width;
  final double height;

  double get left => centerX - (width / 2.0);
  double get right => centerX + (width / 2.0);
  double get top => centerY - (height / 2.0);
  double get bottom => centerY + (height / 2.0);
  double get minDimension => width < height ? width : height;
}

class SceneOpticalBoundsProfile {
  const SceneOpticalBoundsProfile({
    required this.id,
    this.offsetXRatio = 0.0,
    this.offsetYRatio = 0.0,
    this.safeZoneRatio = 0.06,
  });

  final String id;
  final double offsetXRatio;
  final double offsetYRatio;
  final double safeZoneRatio;
}

class SceneOpticalBounds {
  const SceneOpticalBounds._();

  static SceneOpticalRect? rectFor(ReFusionSceneProgramElement element) {
    final position = element.properties['position'];
    final x = _readPositionAxis(element.properties, position, axis: 'x');
    final y = _readPositionAxis(element.properties, position, axis: 'y');
    final width = _readDimension(element.properties, const <String>[
      'width',
      'w',
    ]);
    final height = _readDimension(element.properties, const <String>[
      'height',
      'h',
    ]);
    if (x == null || y == null || width == null || height == null) {
      return null;
    }
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return null;
    }
    return SceneOpticalRect(
      centerX: x,
      centerY: y,
      width: width,
      height: height,
    );
  }

  static SceneOpticalBoundsProfile profileFor(
    ReFusionSceneProgramElement element,
  ) {
    final normalizedKind = _normalize(element.kind);
    final text = (element.text ?? '').trim();
    final iconName = _readString(element.properties, const <String>[
      'icon',
      'iconName',
      'glyph',
      'symbol',
      'name',
    ]);
    if (text.length == 1 && normalizedKind == 'text') {
      final glyph = text.toUpperCase();
      if (glyph == 'R') {
        return const SceneOpticalBoundsProfile(
          id: 'glyph.r',
          offsetXRatio: 0.03,
          safeZoneRatio: 0.08,
        );
      }
      if (glyph == 'A' || glyph == 'V' || glyph == 'W') {
        return const SceneOpticalBoundsProfile(
          id: 'glyph.angular',
          offsetYRatio: 0.02,
          safeZoneRatio: 0.08,
        );
      }
      if (glyph == 'O' || glyph == 'C' || glyph == 'G' || glyph == 'S') {
        return const SceneOpticalBoundsProfile(
          id: 'glyph.round',
          safeZoneRatio: 0.08,
        );
      }
      return const SceneOpticalBoundsProfile(
        id: 'glyph.default',
        safeZoneRatio: 0.08,
      );
    }

    final normalizedIcon = _normalize(iconName ?? '');
    if (normalizedIcon == 'plus' || normalizedIcon == 'add') {
      return const SceneOpticalBoundsProfile(
        id: 'icon.plus',
        safeZoneRatio: 0.18,
      );
    }
    if (normalizedIcon == 'send' ||
        normalizedIcon == 'arrowup' ||
        normalizedIcon == 'up') {
      return const SceneOpticalBoundsProfile(
        id: 'icon.send',
        offsetXRatio: -0.01,
        offsetYRatio: -0.01,
        safeZoneRatio: 0.2,
      );
    }

    final brandToken = _readString(element.properties, const <String>[
      'brand',
      'brandId',
      'brandToken',
      'logo',
    ]);
    if (brandToken != null && brandToken.trim().isNotEmpty) {
      return const SceneOpticalBoundsProfile(
        id: 'icon.brand',
        safeZoneRatio: 0.12,
      );
    }

    if (normalizedKind == 'icon') {
      return const SceneOpticalBoundsProfile(
        id: 'icon.default',
        safeZoneRatio: 0.1,
      );
    }

    return const SceneOpticalBoundsProfile(id: 'default');
  }

  static bool looksLikeAlignableIcon(ReFusionSceneProgramElement element) {
    final normalizedKind = _normalize(element.kind);
    if (normalizedKind == 'icon') {
      return true;
    }
    final text = (element.text ?? '').trim();
    if (normalizedKind == 'text' && text.length == 1) {
      return true;
    }
    final iconName = _readString(
      element.properties,
      const <String>['icon', 'iconName', 'glyph', 'symbol'],
    );
    return iconName != null && iconName.trim().isNotEmpty;
  }

  static double? _readPositionAxis(
    Map<String, Object?> properties,
    Object? rawPosition, {
    required String axis,
  }) {
    final direct = _readDouble(properties[axis]);
    if (direct != null) {
      return direct;
    }
    if (axis == 'x') {
      final left = _readDouble(properties['left']);
      if (left != null) {
        return left;
      }
    } else {
      final top = _readDouble(properties['top']);
      if (top != null) {
        return top;
      }
    }

    if (rawPosition is Map<String, Object?>) {
      return _readDouble(rawPosition[axis]);
    }
    if (rawPosition is List && rawPosition.length >= 2) {
      return _readDouble(rawPosition[axis == 'x' ? 0 : 1]);
    }
    return null;
  }

  static double? _readDimension(
    Map<String, Object?> properties,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = _readDouble(properties[key]);
      if (value != null) {
        return value;
      }
    }
    final textFrame = properties['textFrame'];
    if (textFrame is Map<String, Object?>) {
      for (final key in keys) {
        final value = _readDouble(textFrame[key]);
        if (value != null) {
          return value;
        }
      }
    }
    return null;
  }

  static String? _readString(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final raw = map[key];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
    }
    return null;
  }

  static double? _readDouble(Object? raw) {
    if (raw is double) {
      return raw;
    }
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw.trim());
    }
    return null;
  }

  static String _normalize(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '').toLowerCase();
  }
}
