class ReFusionCoreDesignPack {
  const ReFusionCoreDesignPack._();

  static const String version = 'refusion.core-design-pack/v1';

  static const Set<String> iconIds = <String>{
    'arrow-down',
    'arrow-left',
    'arrow-right',
    'arrow-up',
    'bookmark',
    'camera',
    'check',
    'chevron-left',
    'chevron-right',
    'close',
    'comment',
    'crop',
    'heart',
    'image',
    'lock',
    'mic',
    'music',
    'paperclip',
    'pause',
    'play',
    'plus',
    'search',
    'send',
    'settings',
    'share',
    'sparkles',
    'text',
    'user',
    'verified',
    'video',
    'volume',
  };

  static const Set<String> primitiveIds = <String>{
    'rectangle',
    'roundedRectangle',
    'circle',
    'line',
    'solid',
    'text',
    'icon',
  };

  static const Set<String> componentIds = <String>{
    'promptInputBar',
    'socialPostHeader',
    'socialActionRow',
    'avatar',
    'iconButton',
    'badge',
    'card',
  };

  static const Map<String, String> _iconAliases = <String, String>{
    'add': 'plus',
    'attach': 'paperclip',
    'attachment': 'paperclip',
    'back': 'arrow-left',
    'badgecheck': 'verified',
    'chat': 'comment',
    'clip': 'paperclip',
    'commentbubble': 'comment',
    'done': 'check',
    'favorite': 'heart',
    'microphone': 'mic',
    'photo': 'image',
    'profile': 'user',
    'record': 'mic',
    'settingsgear': 'settings',
    'submit': 'send',
    'tick': 'check',
    'verification': 'verified',
    'voice': 'mic',
  };

  static String? normalizeIconId(String rawIconId) {
    final normalized = _normalizeToken(rawIconId);
    if (normalized.isEmpty) {
      return null;
    }
    final direct = _hyphenated(normalized);
    if (iconIds.contains(direct)) {
      return direct;
    }
    return _iconAliases[normalized];
  }

  static bool isSupportedIcon(String rawIconId) {
    return normalizeIconId(rawIconId) != null;
  }

  static String _normalizeToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  static String _hyphenated(String value) {
    return switch (value) {
      'arrowdown' => 'arrow-down',
      'arrowleft' => 'arrow-left',
      'arrowright' => 'arrow-right',
      'arrowup' => 'arrow-up',
      'chevronleft' => 'chevron-left',
      'chevronright' => 'chevron-right',
      _ => value,
    };
  }
}
