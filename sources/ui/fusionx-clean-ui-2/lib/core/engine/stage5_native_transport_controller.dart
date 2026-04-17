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

class Stage5NativeTransportController extends ChangeNotifier {
  Stage5NativeTransportController();

  static const String methodChannelName = 'com.refusion.app/stage5_transport';
  static const String eventChannelName =
      'com.refusion.app/stage5_transport_events';
  static const String previewViewType = 'com.refusion.app/stage5_preview';
  static const String timelineScrubViewType =
      'com.refusion.app/stage5_timeline_scrub';

  static const MethodChannel _methodChannel = MethodChannel(methodChannelName);
  static const EventChannel _eventChannel = EventChannel(eventChannelName);

  Stage5TransportState _state = const Stage5TransportState();
  StreamSubscription<dynamic>? _eventsSubscription;
  bool _isInitializing = false;
  Stage5TransportState get state => _state;

  bool get isPlatformSupported => !kIsWeb && Platform.isAndroid;

  bool get isReady => _state.isReady;

  bool get isPlaying => _state.isPlaying;

  double get currentSeconds => _state.positionSeconds;

  double get durationSeconds => _state.durationSeconds;

  double? get aspectRatio => _state.aspectRatio;

  String? get errorMessage => _state.error;

  bool get isInitializing => _isInitializing;

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

  Future<void> primeScrubPreviewSources(
    List<Map<String, Object?>> sources,
  ) async {
    if (!isPlatformSupported || sources.isEmpty) {
      return;
    }
    await _invokeWithoutResult(
      'primeScrubPreviewSources',
      <String, dynamic>{'sources': sources},
    );
  }

  @override
  void dispose() {
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
