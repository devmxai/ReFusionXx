import 'editor_media_tab.dart';

enum EditorAssetScrubPreviewStatus { idle, preparing, ready, failed }

class EditorAssetItem {
  const EditorAssetItem({
    required this.id,
    required this.tab,
    required this.label,
    required this.tone,
    this.sourceUri,
    this.previewUri,
    this.isImported = false,
    this.durationSeconds,
    this.width,
    this.height,
    this.dateAddedSeconds,
    this.scrubPreviewStatus = EditorAssetScrubPreviewStatus.idle,
    this.scrubFrameIntervalMs,
    this.scrubFrameCount,
    this.scrubExtractedFrameCount,
    this.scrubOverviewFrameIntervalMs,
    this.scrubOverviewFrameCount,
    this.scrubOverviewExtractedFrameCount,
    this.scrubActiveWindowStartMs,
    this.scrubActiveWindowEndMs,
    this.scrubActiveWindowFrameCount,
    this.scrubActiveWindowReadyFrameCount,
    this.scrubIsActiveWindowReady = false,
    this.scrubHasRenderablePreview = false,
    this.scrubStorageTier,
    this.scrubPreviewError,
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
      previewUri: data['previewUri']?.toString(),
      isImported: (data['isImported'] as bool?) ?? false,
      durationSeconds: durationSeconds,
      width: _asInt(data['width']),
      height: _asInt(data['height']),
      dateAddedSeconds: _asInt(data['dateAddedSeconds']),
      scrubPreviewStatus: switch (data['scrubPreviewStatus']?.toString()) {
        'preparing' => EditorAssetScrubPreviewStatus.preparing,
        'ready' => EditorAssetScrubPreviewStatus.ready,
        'failed' => EditorAssetScrubPreviewStatus.failed,
        _ => EditorAssetScrubPreviewStatus.idle,
      },
      scrubFrameIntervalMs: _asInt(data['scrubFrameIntervalMs']),
      scrubFrameCount: _asInt(data['scrubFrameCount']),
      scrubExtractedFrameCount: _asInt(data['scrubExtractedFrameCount']),
      scrubOverviewFrameIntervalMs: _asInt(data['overviewFrameIntervalMs']),
      scrubOverviewFrameCount: _asInt(data['overviewFrameCount']),
      scrubOverviewExtractedFrameCount:
          _asInt(data['overviewExtractedFrameCount']),
      scrubActiveWindowStartMs: _asInt(data['activeWindowStartMs']),
      scrubActiveWindowEndMs: _asInt(data['activeWindowEndMs']),
      scrubActiveWindowFrameCount: _asInt(data['activeWindowFrameCount']),
      scrubActiveWindowReadyFrameCount:
          _asInt(data['activeWindowReadyFrameCount']),
      scrubIsActiveWindowReady: (data['isActiveWindowReady'] as bool?) ?? false,
      scrubHasRenderablePreview:
          (data['hasRenderablePreview'] as bool?) ?? false,
      scrubStorageTier: data['scrubStorageTier']?.toString(),
      scrubPreviewError: data['scrubPreviewError']?.toString(),
    );
  }

  final String id;
  final EditorMediaTab tab;
  final String label;
  final int tone;
  final String? sourceUri;
  final String? previewUri;
  final bool isImported;
  final double? durationSeconds;
  final int? width;
  final int? height;
  final int? dateAddedSeconds;
  final EditorAssetScrubPreviewStatus scrubPreviewStatus;
  final int? scrubFrameIntervalMs;
  final int? scrubFrameCount;
  final int? scrubExtractedFrameCount;
  final int? scrubOverviewFrameIntervalMs;
  final int? scrubOverviewFrameCount;
  final int? scrubOverviewExtractedFrameCount;
  final int? scrubActiveWindowStartMs;
  final int? scrubActiveWindowEndMs;
  final int? scrubActiveWindowFrameCount;
  final int? scrubActiveWindowReadyFrameCount;
  final bool scrubIsActiveWindowReady;
  final bool scrubHasRenderablePreview;
  final String? scrubStorageTier;
  final String? scrubPreviewError;

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
    Object? previewUri = _noChange,
    bool? isImported,
    double? durationSeconds,
    int? width,
    int? height,
    int? dateAddedSeconds,
    EditorAssetScrubPreviewStatus? scrubPreviewStatus,
    Object? scrubFrameIntervalMs = _noChange,
    Object? scrubFrameCount = _noChange,
    Object? scrubExtractedFrameCount = _noChange,
    Object? scrubOverviewFrameIntervalMs = _noChange,
    Object? scrubOverviewFrameCount = _noChange,
    Object? scrubOverviewExtractedFrameCount = _noChange,
    Object? scrubActiveWindowStartMs = _noChange,
    Object? scrubActiveWindowEndMs = _noChange,
    Object? scrubActiveWindowFrameCount = _noChange,
    Object? scrubActiveWindowReadyFrameCount = _noChange,
    bool? scrubIsActiveWindowReady,
    bool? scrubHasRenderablePreview,
    Object? scrubStorageTier = _noChange,
    Object? scrubPreviewError = _noChange,
  }) {
    return EditorAssetItem(
      id: id ?? this.id,
      tab: tab ?? this.tab,
      label: label ?? this.label,
      tone: tone ?? this.tone,
      sourceUri: sourceUri ?? this.sourceUri,
      previewUri: identical(previewUri, _noChange)
          ? this.previewUri
          : previewUri as String?,
      isImported: isImported ?? this.isImported,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      width: width ?? this.width,
      height: height ?? this.height,
      dateAddedSeconds: dateAddedSeconds ?? this.dateAddedSeconds,
      scrubPreviewStatus: scrubPreviewStatus ?? this.scrubPreviewStatus,
      scrubFrameIntervalMs: identical(scrubFrameIntervalMs, _noChange)
          ? this.scrubFrameIntervalMs
          : scrubFrameIntervalMs as int?,
      scrubFrameCount: identical(scrubFrameCount, _noChange)
          ? this.scrubFrameCount
          : scrubFrameCount as int?,
      scrubExtractedFrameCount: identical(scrubExtractedFrameCount, _noChange)
          ? this.scrubExtractedFrameCount
          : scrubExtractedFrameCount as int?,
      scrubOverviewFrameIntervalMs:
          identical(scrubOverviewFrameIntervalMs, _noChange)
              ? this.scrubOverviewFrameIntervalMs
              : scrubOverviewFrameIntervalMs as int?,
      scrubOverviewFrameCount: identical(scrubOverviewFrameCount, _noChange)
          ? this.scrubOverviewFrameCount
          : scrubOverviewFrameCount as int?,
      scrubOverviewExtractedFrameCount:
          identical(scrubOverviewExtractedFrameCount, _noChange)
              ? this.scrubOverviewExtractedFrameCount
              : scrubOverviewExtractedFrameCount as int?,
      scrubActiveWindowStartMs: identical(scrubActiveWindowStartMs, _noChange)
          ? this.scrubActiveWindowStartMs
          : scrubActiveWindowStartMs as int?,
      scrubActiveWindowEndMs: identical(scrubActiveWindowEndMs, _noChange)
          ? this.scrubActiveWindowEndMs
          : scrubActiveWindowEndMs as int?,
      scrubActiveWindowFrameCount:
          identical(scrubActiveWindowFrameCount, _noChange)
              ? this.scrubActiveWindowFrameCount
              : scrubActiveWindowFrameCount as int?,
      scrubActiveWindowReadyFrameCount:
          identical(scrubActiveWindowReadyFrameCount, _noChange)
              ? this.scrubActiveWindowReadyFrameCount
              : scrubActiveWindowReadyFrameCount as int?,
      scrubIsActiveWindowReady:
          scrubIsActiveWindowReady ?? this.scrubIsActiveWindowReady,
      scrubHasRenderablePreview:
          scrubHasRenderablePreview ?? this.scrubHasRenderablePreview,
      scrubStorageTier: identical(scrubStorageTier, _noChange)
          ? this.scrubStorageTier
          : scrubStorageTier as String?,
      scrubPreviewError: identical(scrubPreviewError, _noChange)
          ? this.scrubPreviewError
          : scrubPreviewError as String?,
    );
  }
}

const Object _noChange = Object();

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
