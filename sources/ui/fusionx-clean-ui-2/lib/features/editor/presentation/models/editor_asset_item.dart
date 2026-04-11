import 'editor_media_tab.dart';

class EditorAssetItem {
  const EditorAssetItem({
    required this.id,
    required this.tab,
    required this.label,
    required this.tone,
    this.sourceUri,
    this.isImported = false,
    this.durationSeconds,
    this.width,
    this.height,
    this.dateAddedSeconds,
  });

  factory EditorAssetItem.fromPlatformMap(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? 'asset-unknown';
    final tab = switch (data['tab']?.toString()) {
      'image' => EditorMediaTab.image,
      'video' => EditorMediaTab.video,
      'audio' => EditorMediaTab.audio,
      'text' => EditorMediaTab.text,
      'lipSync' => EditorMediaTab.lipSync,
      _ => EditorMediaTab.video,
    };
    final durationMs = data['durationMs'];
    final durationSeconds = switch (durationMs) {
      int value => value <= 0 ? null : value / 1000.0,
      double value => value <= 0 ? null : value / 1000.0,
      _ => null,
    };
    return EditorAssetItem(
      id: id,
      tab: tab,
      label: data['label']?.toString() ?? 'Untitled',
      tone: _toneForId(id),
      sourceUri: data['sourceUri']?.toString(),
      isImported: (data['isImported'] as bool?) ?? false,
      durationSeconds: durationSeconds,
      width: _asInt(data['width']),
      height: _asInt(data['height']),
      dateAddedSeconds: _asInt(data['dateAddedSeconds']),
    );
  }

  final String id;
  final EditorMediaTab tab;
  final String label;
  final int tone;
  final String? sourceUri;
  final bool isImported;
  final double? durationSeconds;
  final int? width;
  final int? height;
  final int? dateAddedSeconds;

  bool get isVisual => tab == EditorMediaTab.video || tab == EditorMediaTab.image;

  double? get aspectRatio {
    if (width == null || height == null || width == 0 || height == 0) {
      return null;
    }
    return width! / height!;
  }

  bool get hasFilePath =>
      sourceUri != null &&
      sourceUri!.isNotEmpty &&
      !sourceUri!.startsWith('content://');

  EditorAssetItem copyWith({
    String? id,
    EditorMediaTab? tab,
    String? label,
    int? tone,
    String? sourceUri,
    bool? isImported,
    double? durationSeconds,
    int? width,
    int? height,
    int? dateAddedSeconds,
  }) {
    return EditorAssetItem(
      id: id ?? this.id,
      tab: tab ?? this.tab,
      label: label ?? this.label,
      tone: tone ?? this.tone,
      sourceUri: sourceUri ?? this.sourceUri,
      isImported: isImported ?? this.isImported,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      width: width ?? this.width,
      height: height ?? this.height,
      dateAddedSeconds: dateAddedSeconds ?? this.dateAddedSeconds,
    );
  }
}

int _toneForId(String id) {
  final sum = id.codeUnits.fold<int>(0, (value, codeUnit) => value + codeUnit);
  return sum % 100;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  return null;
}
