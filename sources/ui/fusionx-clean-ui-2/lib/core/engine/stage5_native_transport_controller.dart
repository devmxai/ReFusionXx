import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Stage5TransportState {
  const Stage5TransportState({
    this.isReady = false,
    this.isPlaying = false,
    this.durationMs = 0,
    this.positionMs = 0,
    this.playbackState = 0,
    this.videoWidth = 0,
    this.videoHeight = 0,
    this.isScrubbing = false,
    this.isScrubSettling = false,
    this.sourceKind = 'idle',
    this.sourceLabel,
    this.error,
  });

  final bool isReady;
  final bool isPlaying;
  final int durationMs;
  final int positionMs;
  final int playbackState;
  final int videoWidth;
  final int videoHeight;
  final bool isScrubbing;
  final bool isScrubSettling;
  final String sourceKind;
  final String? sourceLabel;
  final String? error;

  double get durationSeconds => durationMs <= 0 ? 0 : durationMs / 1000.0;

  double get positionSeconds => positionMs <= 0 ? 0 : positionMs / 1000.0;

  double? get aspectRatio {
    if (videoWidth <= 0 || videoHeight <= 0) {
      return null;
    }
    return videoWidth / videoHeight;
  }

  Stage5TransportState copyWith({
    bool? isReady,
    bool? isPlaying,
    int? durationMs,
    int? positionMs,
    int? playbackState,
    int? videoWidth,
    int? videoHeight,
    bool? isScrubbing,
    bool? isScrubSettling,
    String? sourceKind,
    String? sourceLabel,
    Object? error = _noChange,
  }) {
    return Stage5TransportState(
      isReady: isReady ?? this.isReady,
      isPlaying: isPlaying ?? this.isPlaying,
      durationMs: durationMs ?? this.durationMs,
      positionMs: positionMs ?? this.positionMs,
      playbackState: playbackState ?? this.playbackState,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      isScrubbing: isScrubbing ?? this.isScrubbing,
      isScrubSettling: isScrubSettling ?? this.isScrubSettling,
      sourceKind: sourceKind ?? this.sourceKind,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      error: identical(error, _noChange) ? this.error : error as String?,
    );
  }
}

enum Stage5ScrubFrameStoreState { idle, preparing, ready, failed }

enum Stage5ScrubProxyState { idle, preparing, ready, failed }

@immutable
class Stage5ScrubProxyStatus {
  const Stage5ScrubProxyStatus({
    required this.assetId,
    required this.sourceUri,
    required this.state,
    this.previewUri,
    this.targetWidth,
    this.targetHeight,
    this.error,
  });

  factory Stage5ScrubProxyStatus.fromMap(Map<String, dynamic> map) {
    final stateValue = map['state']?.toString();
    return Stage5ScrubProxyStatus(
      assetId: map['assetId']?.toString() ?? '',
      sourceUri: map['sourceUri']?.toString() ?? '',
      state: switch (stateValue) {
        'preparing' => Stage5ScrubProxyState.preparing,
        'ready' => Stage5ScrubProxyState.ready,
        'failed' => Stage5ScrubProxyState.failed,
        _ => Stage5ScrubProxyState.idle,
      },
      previewUri: map['previewUri']?.toString(),
      targetWidth: _asInt(map['targetWidth']),
      targetHeight: _asInt(map['targetHeight']),
      error: map['error']?.toString(),
    );
  }

  final String assetId;
  final String sourceUri;
  final Stage5ScrubProxyState state;
  final String? previewUri;
  final int? targetWidth;
  final int? targetHeight;
  final String? error;

  bool get isReady =>
      state == Stage5ScrubProxyState.ready &&
      previewUri != null &&
      previewUri!.isNotEmpty;
}

@immutable
class Stage5ScrubFrameStoreStatus {
  const Stage5ScrubFrameStoreStatus({
    required this.assetId,
    required this.sourceUri,
    required this.state,
    required this.frameIntervalMs,
    required this.frameCount,
    required this.extractedFrameCount,
    required this.overviewFrameIntervalMs,
    required this.overviewFrameCount,
    required this.overviewExtractedFrameCount,
    required this.activeWindowFrameCount,
    required this.activeWindowReadyFrameCount,
    required this.isActiveWindowReady,
    required this.hasRenderablePreview,
    this.activeWindowStartMs,
    this.activeWindowEndMs,
    this.storageTier,
    this.error,
  });

  factory Stage5ScrubFrameStoreStatus.fromMap(Map<String, dynamic> map) {
    final stateValue = map['state']?.toString();
    return Stage5ScrubFrameStoreStatus(
      assetId: map['assetId']?.toString() ?? '',
      sourceUri: map['sourceUri']?.toString() ?? '',
      state: switch (stateValue) {
        'preparing' => Stage5ScrubFrameStoreState.preparing,
        'ready' => Stage5ScrubFrameStoreState.ready,
        'failed' => Stage5ScrubFrameStoreState.failed,
        _ => Stage5ScrubFrameStoreState.idle,
      },
      frameIntervalMs: _asInt(map['frameIntervalMs']) ?? 0,
      frameCount: _asInt(map['frameCount']) ?? 0,
      extractedFrameCount: _asInt(map['extractedFrameCount']) ?? 0,
      overviewFrameIntervalMs: _asInt(map['overviewFrameIntervalMs']) ?? 0,
      overviewFrameCount: _asInt(map['overviewFrameCount']) ?? 0,
      overviewExtractedFrameCount:
          _asInt(map['overviewExtractedFrameCount']) ?? 0,
      activeWindowStartMs: _asInt(map['activeWindowStartMs']),
      activeWindowEndMs: _asInt(map['activeWindowEndMs']),
      activeWindowFrameCount: _asInt(map['activeWindowFrameCount']) ?? 0,
      activeWindowReadyFrameCount:
          _asInt(map['activeWindowReadyFrameCount']) ?? 0,
      isActiveWindowReady: map['isActiveWindowReady'] == true,
      hasRenderablePreview: map['hasRenderablePreview'] == true,
      storageTier: map['storageTier']?.toString(),
      error: map['error']?.toString(),
    );
  }

  final String assetId;
  final String sourceUri;
  final Stage5ScrubFrameStoreState state;
  final int frameIntervalMs;
  final int frameCount;
  final int extractedFrameCount;
  final int overviewFrameIntervalMs;
  final int overviewFrameCount;
  final int overviewExtractedFrameCount;
  final int? activeWindowStartMs;
  final int? activeWindowEndMs;
  final int activeWindowFrameCount;
  final int activeWindowReadyFrameCount;
  final bool isActiveWindowReady;
  final bool hasRenderablePreview;
  final String? storageTier;
  final String? error;

  bool get isReady => state == Stage5ScrubFrameStoreState.ready;
}

class Stage5NativeTransportController extends ChangeNotifier {
  Stage5NativeTransportController();

  static const String methodChannelName = 'com.refusion.app/stage5_transport';
  static const String eventChannelName =
      'com.refusion.app/stage5_transport_events';
  static const String previewViewType = 'com.refusion.app/stage5_preview';
  static const String timelineScrubViewType =
      'com.refusion.app/stage5_timeline_scrub';
  static const int _defaultScrubPreviewTextureWidth = 480;
  static const int _defaultScrubPreviewTextureHeight = 854;

  static const MethodChannel _methodChannel = MethodChannel(methodChannelName);
  static const EventChannel _eventChannel = EventChannel(eventChannelName);

  Stage5TransportState _state = const Stage5TransportState();
  StreamSubscription<dynamic>? _eventsSubscription;
  bool _isInitializing = false;
  int? _scrubPreviewTextureId;
  bool _isScrubPreviewTextureVisible = false;
  Stage5TransportState get state => _state;

  bool get isPlatformSupported => !kIsWeb && Platform.isAndroid;

  bool get isReady => _state.isReady;

  bool get isPlaying => _state.isPlaying;

  double get currentSeconds => _state.positionSeconds;

  double get durationSeconds => _state.durationSeconds;

  double? get aspectRatio => _state.aspectRatio;

  String? get errorMessage => _state.error;

  bool get isInitializing => _isInitializing;

  int? get scrubPreviewTextureId => _scrubPreviewTextureId;

  bool get isScrubPreviewTextureVisible => _isScrubPreviewTextureVisible;

  void hideScrubPreviewTexture() {
    if (_isScrubPreviewTextureVisible) {
      _isScrubPreviewTextureVisible = false;
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    if (!isPlatformSupported) {
      _state = _state.copyWith(
        error: 'Stage 5 preview is Android-only in this slice.',
      );
      notifyListeners();
      return;
    }

    _eventsSubscription ??= _eventChannel.receiveBroadcastStream().listen(
          _handleEvent,
          onError: _handleError,
        );

    _isInitializing = true;
    notifyListeners();
    try {
      final result =
          await _methodChannel.invokeMethod<dynamic>('initializeTransport');
      _applyStateMap(_normalizeMap(result));
    } catch (error) {
      _state = _state.copyWith(error: error.toString());
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<DeviceMediaPageResult> loadDeviceMediaPage(
    String mediaKind, {
    int offset = 0,
    int limit = 24,
  }) async {
    if (!isPlatformSupported) {
      return const DeviceMediaPageResult(
        items: <Map<String, dynamic>>[],
        nextOffset: 0,
        hasMore: false,
      );
    }
    final result = await _methodChannel.invokeMethod<dynamic>(
      'loadDeviceMedia',
      <String, dynamic>{
        'tab': mediaKind,
        'offset': offset,
        'limit': limit,
      },
    );
    final normalized = _normalizeMap(result);
    final rawItems = normalized['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<Object?, Object?>>()
            .map(
              (entry) => entry.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final nextOffset = switch (normalized['nextOffset']) {
      int value => value,
      double value => value.round(),
      _ => offset + items.length,
    };
    final hasMore = normalized['hasMore'] == true;
    return DeviceMediaPageResult(
      items: items,
      nextOffset: nextOffset,
      hasMore: hasMore,
    );
  }

  Future<List<Map<String, dynamic>>> loadDeviceMedia(String mediaKind) async {
    final page = await loadDeviceMediaPage(mediaKind);
    if (page.items.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    return page.items;
  }

  Future<Uint8List?> loadMediaThumbnail({
    required String sourceUri,
    int targetWidth = 192,
    int targetHeight = 288,
  }) async {
    if (!isPlatformSupported) {
      return null;
    }
    final result = await _methodChannel.invokeMethod<Uint8List>(
      'loadMediaThumbnail',
      <String, dynamic>{
        'sourceUri': sourceUri,
        'targetWidth': targetWidth,
        'targetHeight': targetHeight,
      },
    );
    return result;
  }

  Future<Map<String, Uint8List?>> loadMediaThumbnails({
    required List<Map<String, String>> requests,
    int targetWidth = 192,
    int targetHeight = 288,
  }) async {
    if (!isPlatformSupported || requests.isEmpty) {
      return const <String, Uint8List?>{};
    }
    final result = await _methodChannel.invokeMethod<dynamic>(
      'loadMediaThumbnails',
      <String, dynamic>{
        'requests': requests,
        'targetWidth': targetWidth,
        'targetHeight': targetHeight,
      },
    );
    if (result is! Map) {
      return const <String, Uint8List?>{};
    }
    final thumbnails = <String, Uint8List?>{};
    result.forEach((key, value) {
      final assetId = key?.toString();
      if (assetId == null || assetId.isEmpty) {
        return;
      }
      thumbnails[assetId] = value is Uint8List ? value : null;
    });
    return thumbnails;
  }

  Future<Uint8List?> loadMediaFramePreview({
    required String sourceUri,
    required int positionMs,
    int targetWidth = 320,
    int targetHeight = 568,
  }) async {
    if (!isPlatformSupported) {
      return null;
    }
    final result = await _methodChannel.invokeMethod<Uint8List>(
      'loadMediaFramePreview',
      <String, dynamic>{
        'sourceUri': sourceUri,
        'positionMs': positionMs < 0 ? 0 : positionMs,
        'targetWidth': targetWidth,
        'targetHeight': targetHeight,
      },
    );
    return result;
  }

  Future<Stage5ScrubFrameStoreStatus?> prepareScrubFrameStore({
    required String assetId,
    required String sourceUri,
    required int durationMs,
    int? sourceWidth,
    int? sourceHeight,
    int targetWidth = 240,
    int targetHeight = 426,
    int? initialPositionMs,
  }) async {
    if (!isPlatformSupported) {
      return null;
    }
    final result = await _methodChannel.invokeMethod<dynamic>(
      'prepareScrubFrameStore',
      <String, dynamic>{
        'assetId': assetId,
        'sourceUri': sourceUri,
        'durationMs': durationMs < 0 ? 0 : durationMs,
        'sourceWidth': sourceWidth,
        'sourceHeight': sourceHeight,
        'targetWidth': targetWidth,
        'targetHeight': targetHeight,
        'initialPositionMs': initialPositionMs,
      },
    );
    final normalized = _normalizeMap(result);
    if (normalized.isEmpty) {
      return null;
    }
    return Stage5ScrubFrameStoreStatus.fromMap(normalized);
  }

  Future<Stage5ScrubFrameStoreStatus?> getScrubFrameStoreStatus({
    required String assetId,
  }) async {
    if (!isPlatformSupported) {
      return null;
    }
    final result = await _methodChannel.invokeMethod<dynamic>(
      'getScrubFrameStoreStatus',
      <String, dynamic>{
        'assetId': assetId,
      },
    );
    final normalized = _normalizeMap(result);
    if (normalized.isEmpty) {
      return null;
    }
    return Stage5ScrubFrameStoreStatus.fromMap(normalized);
  }

  Future<Stage5ScrubFrameStoreStatus?> requestScrubFrameWindow({
    required String assetId,
    required int positionMs,
    int radiusFrames = 25,
  }) async {
    if (!isPlatformSupported) {
      return null;
    }
    final result = await _methodChannel.invokeMethod<dynamic>(
      'requestScrubFrameWindow',
      <String, dynamic>{
        'assetId': assetId,
        'positionMs': positionMs < 0 ? 0 : positionMs,
        'radiusFrames': radiusFrames < 1 ? 1 : radiusFrames,
      },
    );
    final normalized = _normalizeMap(result);
    if (normalized.isEmpty) {
      return null;
    }
    return Stage5ScrubFrameStoreStatus.fromMap(normalized);
  }

  Future<int?> ensureScrubPreviewTexture({
    int targetWidth = _defaultScrubPreviewTextureWidth,
    int targetHeight = _defaultScrubPreviewTextureHeight,
  }) async {
    if (!isPlatformSupported) {
      return null;
    }
    final textureId = await _methodChannel.invokeMethod<int>(
      'ensureScrubPreviewTexture',
      <String, dynamic>{
        'targetWidth': targetWidth,
        'targetHeight': targetHeight,
      },
    );
    _scrubPreviewTextureId = textureId;
    return textureId;
  }

  Future<bool> beginScrubPreviewTextureSession({
    required String scrubStoreKey,
    required int positionMs,
    int targetWidth = _defaultScrubPreviewTextureWidth,
    int targetHeight = _defaultScrubPreviewTextureHeight,
  }) async {
    if (!isPlatformSupported) {
      return false;
    }
    await ensureScrubPreviewTexture(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final rendered =
        await _methodChannel.invokeMethod<bool>(
      'beginScrubPreviewTextureSession',
      <String, dynamic>{
        'scrubStoreKey': scrubStoreKey,
        'positionMs': positionMs < 0 ? 0 : positionMs,
        'targetWidth': targetWidth,
        'targetHeight': targetHeight,
      },
    ) ??
            false;
    if (rendered &&
        !_isScrubPreviewTextureVisible &&
        _scrubPreviewTextureId != null) {
      _isScrubPreviewTextureVisible = true;
      notifyListeners();
    }
    return rendered;
  }

  Future<bool> updateScrubPreviewTextureTarget({
    required String scrubStoreKey,
    required int positionMs,
    int targetWidth = _defaultScrubPreviewTextureWidth,
    int targetHeight = _defaultScrubPreviewTextureHeight,
  }) async {
    if (!isPlatformSupported) {
      return false;
    }
    final rendered =
        await _methodChannel.invokeMethod<bool>(
      'updateScrubPreviewTextureTarget',
      <String, dynamic>{
        'scrubStoreKey': scrubStoreKey,
        'positionMs': positionMs < 0 ? 0 : positionMs,
        'targetWidth': targetWidth,
        'targetHeight': targetHeight,
      },
    ) ??
            false;
    if (rendered &&
        !_isScrubPreviewTextureVisible &&
        _scrubPreviewTextureId != null) {
      _isScrubPreviewTextureVisible = true;
      notifyListeners();
    }
    return rendered;
  }

  Future<void> clearScrubPreviewTexture() async {
    if (!isPlatformSupported) {
      return;
    }
    hideScrubPreviewTexture();
  }

  Future<void> disposeScrubPreviewTexture() async {
    if (!isPlatformSupported) {
      return;
    }
    await _methodChannel.invokeMethod<void>('disposeScrubPreviewTexture');
    final hadTexture =
        _scrubPreviewTextureId != null || _isScrubPreviewTextureVisible;
    _scrubPreviewTextureId = null;
    _isScrubPreviewTextureVisible = false;
    if (hadTexture) {
      notifyListeners();
    }
  }

  Future<Stage5ScrubProxyStatus?> prepareScrubProxy({
    required String assetId,
    required String sourceUri,
    required int durationMs,
    int? sourceWidth,
    int? sourceHeight,
  }) async {
    if (!isPlatformSupported) {
      return null;
    }
    final result = await _methodChannel.invokeMethod<dynamic>(
      'prepareScrubProxy',
      <String, dynamic>{
        'assetId': assetId,
        'sourceUri': sourceUri,
        'durationMs': durationMs < 0 ? 0 : durationMs,
        'sourceWidth': sourceWidth,
        'sourceHeight': sourceHeight,
      },
    );
    final normalized = _normalizeMap(result);
    if (normalized.isEmpty) {
      return null;
    }
    return Stage5ScrubProxyStatus.fromMap(normalized);
  }

  Future<Stage5ScrubProxyStatus?> getScrubProxyStatus({
    required String assetId,
  }) async {
    if (!isPlatformSupported) {
      return null;
    }
    final result = await _methodChannel.invokeMethod<dynamic>(
      'getScrubProxyStatus',
      <String, dynamic>{'assetId': assetId},
    );
    final normalized = _normalizeMap(result);
    if (normalized.isEmpty) {
      return null;
    }
    return Stage5ScrubProxyStatus.fromMap(normalized);
  }

  Future<void> endScrubPreviewTextureSession() async {
    if (!isPlatformSupported) {
      return;
    }
    await _methodChannel.invokeMethod<void>('endScrubPreviewTextureSession');
    hideScrubPreviewTexture();
  }

  Future<Stage5TransportState?> prepareImportedMedia({
    required String sourceUri,
    required String sourceLabel,
  }) async {
    if (!isPlatformSupported) {
      return null;
    }
    try {
      final result = await _methodChannel.invokeMethod<dynamic>(
        'prepareImportedMedia',
        <String, dynamic>{
          'sourceUri': sourceUri,
          'sourceLabel': sourceLabel,
        },
      );
      if (_applyStateMap(_normalizeMap(result))) {
        notifyListeners();
      }
      return _state;
    } catch (error) {
      final nextState = _state.copyWith(error: error.toString());
      if (!_statesEqual(_state, nextState)) {
        _state = nextState;
        notifyListeners();
      }
      return null;
    }
  }

  Future<Stage5TransportState?> prepareTimelineSegments({
    required List<Map<String, dynamic>> segments,
    int startPositionMs = 0,
  }) async {
    if (!isPlatformSupported) {
      return null;
    }
    try {
      final result = await _methodChannel.invokeMethod<dynamic>(
        'prepareTimelineSegments',
        <String, dynamic>{
          'segments': segments,
          'startPositionMs': startPositionMs < 0 ? 0 : startPositionMs,
        },
      );
      if (_applyStateMap(_normalizeMap(result))) {
        notifyListeners();
      }
      return _state;
    } catch (error) {
      final nextState = _state.copyWith(error: error.toString());
      if (!_statesEqual(_state, nextState)) {
        _state = nextState;
        notifyListeners();
      }
      return null;
    }
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
      return;
    }
    await play();
  }

  Future<void> play() async {
    _applyOptimisticPlaybackState(true);
    await _invokeWithoutResult('play');
  }

  Future<void> pause() async {
    _applyOptimisticPlaybackState(false);
    await _invokeWithoutResult('pause');
  }

  Future<void> beginScrubSession() async {
    await _invokeWithoutResult('beginScrubSession');
  }

  Future<void> seekToSeconds(double seconds) async {
    final clampedSeconds = seconds.isNaN || seconds.isInfinite
        ? 0.0
        : seconds
            .clamp(0.0, durationSeconds > 0 ? durationSeconds : seconds)
            .toDouble();
    await seekToPositionMs((clampedSeconds * 1000).round());
  }

  Future<void> seekToPositionMs(int positionMs) async {
    final clampedPositionMs = positionMs < 0 ? 0 : positionMs;
    await _invokeWithoutResult(
      'seekTo',
      <String, dynamic>{'positionMs': clampedPositionMs},
    );
  }

  Future<void> settleAfterScrubPositionMs(int positionMs) async {
    final clampedPositionMs = positionMs < 0 ? 0 : positionMs;
    await _invokeWithoutResult(
      'settleAfterScrub',
      <String, dynamic>{'positionMs': clampedPositionMs},
    );
  }

  Future<Map<String, dynamic>> getScrubDiagnostics() async {
    if (!isPlatformSupported) {
      return const <String, dynamic>{};
    }
    final result =
        await _methodChannel.invokeMethod<dynamic>('getScrubDiagnostics');
    return _normalizeMap(result);
  }

  Future<void> resetScrubDiagnostics() async {
    await _invokeWithoutResult('resetScrubDiagnostics');
  }

  @override
  void dispose() {
    unawaited(endScrubPreviewTextureSession());
    unawaited(disposeScrubPreviewTexture());
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    super.dispose();
  }

  Future<void> _invokeWithoutResult(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (!isPlatformSupported) {
      return;
    }
    try {
      await _methodChannel.invokeMethod<void>(method, arguments);
    } catch (error) {
      final nextState = _state.copyWith(error: error.toString());
      if (!_statesEqual(_state, nextState)) {
        _state = nextState;
        notifyListeners();
      }
    }
  }

  void _handleEvent(dynamic event) {
    if (_applyStateMap(_normalizeMap(event))) {
      notifyListeners();
    }
  }

  void _handleError(Object error) {
    final nextState = _state.copyWith(error: error.toString());
    if (_statesEqual(_state, nextState)) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  void _applyOptimisticPlaybackState(bool isPlaying) {
    final nextState = _state.copyWith(
      isPlaying: isPlaying,
      error: null,
    );
    if (_statesEqual(_state, nextState)) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  bool _applyStateMap(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return false;
    }
    final nextState = _state.copyWith(
      isReady: (data['isReady'] as bool?) ?? _state.isReady,
      isPlaying: (data['isPlaying'] as bool?) ?? _state.isPlaying,
      durationMs: _asInt(data['durationMs']) ?? _state.durationMs,
      positionMs: _asInt(data['positionMs']) ?? _state.positionMs,
      playbackState: _asInt(data['playbackState']) ?? _state.playbackState,
      videoWidth: _asInt(data['videoWidth']) ?? _state.videoWidth,
      videoHeight: _asInt(data['videoHeight']) ?? _state.videoHeight,
      isScrubbing: (data['isScrubbing'] as bool?) ?? _state.isScrubbing,
      isScrubSettling:
          (data['isScrubSettling'] as bool?) ?? _state.isScrubSettling,
      sourceKind: data['sourceKind'] as String? ?? _state.sourceKind,
      sourceLabel: data['sourceLabel'] as String? ?? _state.sourceLabel,
      error:
          data.containsKey('error') ? data['error'] as String? : _state.error,
    );
    if (_statesEqual(_state, nextState)) {
      return false;
    }
    _state = nextState;
    return true;
  }

  bool _statesEqual(Stage5TransportState left, Stage5TransportState right) {
    return left.isReady == right.isReady &&
        left.isPlaying == right.isPlaying &&
        left.durationMs == right.durationMs &&
        left.positionMs == right.positionMs &&
        left.playbackState == right.playbackState &&
        left.videoWidth == right.videoWidth &&
        left.videoHeight == right.videoHeight &&
        left.isScrubbing == right.isScrubbing &&
        left.isScrubSettling == right.isScrubSettling &&
        left.sourceKind == right.sourceKind &&
        left.sourceLabel == right.sourceLabel &&
        left.error == right.error;
  }

  Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<Object?, Object?>) {
      return value.map(
        (key, entryValue) => MapEntry(key.toString(), entryValue),
      );
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    return const <String, dynamic>{};
  }

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

class DeviceMediaPageResult {
  const DeviceMediaPageResult({
    required this.items,
    required this.nextOffset,
    required this.hasMore,
  });

  final List<Map<String, dynamic>> items;
  final int nextOffset;
  final bool hasMore;
}

const Object _noChange = Object();
