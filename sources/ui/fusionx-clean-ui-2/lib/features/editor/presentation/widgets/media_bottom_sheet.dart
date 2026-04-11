import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/editor_asset_item.dart';
import '../models/editor_media_tab.dart';

class MediaSheetPageResult {
  const MediaSheetPageResult({
    required this.hasMore,
    required this.loadedCount,
  });

  final bool hasMore;
  final int loadedCount;
}

class MediaBottomSheet extends StatefulWidget {
  const MediaBottomSheet({
    super.key,
    required this.initialTab,
    required this.assetsListenable,
    required this.loadingListenable,
    required this.errorListenable,
    required this.onTabRequested,
    required this.onLoadMoreRequested,
    required this.onAssetAdd,
    required this.thumbnailBatchLoader,
  });

  final EditorMediaTab initialTab;
  final ValueListenable<List<EditorAssetItem>> assetsListenable;
  final ValueListenable<bool> loadingListenable;
  final ValueListenable<String?> errorListenable;
  final Future<MediaSheetPageResult> Function(EditorMediaTab tab) onTabRequested;
  final Future<MediaSheetPageResult> Function(EditorMediaTab tab)
      onLoadMoreRequested;
  final Future<void> Function(EditorAssetItem asset) onAssetAdd;
  final Future<Map<String, Uint8List?>> Function(List<EditorAssetItem> assets)
      thumbnailBatchLoader;

  @override
  State<MediaBottomSheet> createState() => _MediaBottomSheetState();
}

class _MediaBottomSheetState extends State<MediaBottomSheet> {
  late EditorMediaTab _activeTab;
  String? _selectedAssetId;
  final Map<String, ValueNotifier<Uint8List?>> _thumbnailNotifiers =
      <String, ValueNotifier<Uint8List?>>{};
  final Set<String> _thumbnailRequestsInFlight = <String>{};
  Timer? _thumbnailWarmupDebounce;
  String? _pendingWarmupSignature;
  final Map<EditorMediaTab, int> _knownAssetCountByTab = <EditorMediaTab, int>{};
  final Map<EditorMediaTab, bool> _hasMoreByTab = <EditorMediaTab, bool>{};
  final Map<EditorMediaTab, bool> _isPageLoadingByTab = <EditorMediaTab, bool>{};

  static const List<EditorMediaTab> _tabs = <EditorMediaTab>[
    EditorMediaTab.video,
    EditorMediaTab.image,
  ];

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab == EditorMediaTab.image
        ? EditorMediaTab.image
        : EditorMediaTab.video;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestTabAssets(_activeTab);
    });
  }

  @override
  void dispose() {
    _thumbnailWarmupDebounce?.cancel();
    for (final notifier in _thumbnailNotifiers.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  Future<void> _requestTabAssets(EditorMediaTab tab) async {
    setState(() {
      _isPageLoadingByTab[tab] = true;
    });
    try {
      final page = await widget.onTabRequested(tab);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasMoreByTab[tab] = page.hasMore;
        _isPageLoadingByTab[tab] = false;
        _knownAssetCountByTab[tab] = 0;
        _pendingWarmupSignature = null;
      });
      _warmupInitialWindowForTab(tab);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPageLoadingByTab[tab] = false;
      });
    }
  }

  Future<void> _loadMoreAssets(EditorMediaTab tab) async {
    if (_isPageLoadingByTab[tab] == true || _hasMoreByTab[tab] == false) {
      return;
    }
    setState(() {
      _isPageLoadingByTab[tab] = true;
    });
    try {
      final page = await widget.onLoadMoreRequested(tab);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasMoreByTab[tab] = page.hasMore;
        _isPageLoadingByTab[tab] = false;
      });
      _warmupInitialWindowForTab(tab);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPageLoadingByTab[tab] = false;
      });
    }
  }

  void _scheduleThumbnailWarmup(
    List<EditorAssetItem> filtered, {
    required int startIndex,
    required int endIndex,
    bool immediate = false,
  }) {
    if (filtered.isEmpty) {
      return;
    }
    final clampedStart = startIndex.clamp(0, filtered.length - 1).toInt();
    final clampedEnd = endIndex.clamp(clampedStart + 1, filtered.length).toInt();
    final signature =
        '${_activeTab.name}:${filtered.length}:$clampedStart:$clampedEnd';
    if (_pendingWarmupSignature == signature) {
      return;
    }
    _pendingWarmupSignature = signature;
    _thumbnailWarmupDebounce?.cancel();
    void launch() {
      if (!mounted) {
        return;
      }
      final windowItems = filtered.sublist(clampedStart, clampedEnd);
      unawaited(_warmupThumbnails(windowItems, signature));
    }
    if (immediate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => launch());
      return;
    }
    _thumbnailWarmupDebounce = Timer(const Duration(milliseconds: 8), launch);
  }

  void _warmupInitialWindowForTab(EditorMediaTab tab) {
    final filtered = widget.assetsListenable.value
        .where((item) => item.tab == tab)
        .toList(growable: false);
    if (filtered.isEmpty) {
      return;
    }
    final initialCount = filtered.length < 24 ? filtered.length : 24;
    _scheduleThumbnailWarmup(
      filtered,
      startIndex: 0,
      endIndex: initialCount,
      immediate: true,
    );
  }

  ValueNotifier<Uint8List?> _thumbnailNotifierFor(String assetId) {
    return _thumbnailNotifiers.putIfAbsent(
      assetId,
      () => ValueNotifier<Uint8List?>(null),
    );
  }

  Future<void> _warmupThumbnails(
    List<EditorAssetItem> windowItems,
    String signature,
  ) async {
    final batch = <EditorAssetItem>[
      for (final item in windowItems)
        if (item.isVisual &&
            _thumbnailNotifierFor(item.id).value == null &&
            !_thumbnailRequestsInFlight.contains(item.id) &&
            item.sourceUri != null &&
            item.sourceUri!.isNotEmpty)
          item,
    ];
    if (batch.isEmpty) {
      if (_pendingWarmupSignature == signature) {
        _pendingWarmupSignature = null;
      }
      return;
    }
    for (final item in batch) {
      _thumbnailRequestsInFlight.add(item.id);
    }
    final result = await widget.thumbnailBatchLoader(batch);
    if (!mounted) {
      return;
    }
    for (final item in batch) {
      _thumbnailRequestsInFlight.remove(item.id);
      final notifier = _thumbnailNotifierFor(item.id);
      final bytes = result[item.id];
      if (notifier.value != null || bytes == null || bytes.isEmpty) {
        continue;
      }
      notifier.value = bytes;
    }
    if (_pendingWarmupSignature == signature) {
      _pendingWarmupSignature = null;
    }
  }

  bool _handleGridScroll({
    required ScrollNotification notification,
    required ScrollMetrics metrics,
    required List<EditorAssetItem> filtered,
    required double rowExtent,
  }) {
    if (filtered.isEmpty) {
      return false;
    }
    if (metrics.extentAfter < rowExtent * 6 &&
        _hasMoreByTab[_activeTab] == true &&
        _isPageLoadingByTab[_activeTab] != true) {
      unawaited(_loadMoreAssets(_activeTab));
    }
    final isIdleScroll =
        notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle);
    if (!isIdleScroll) {
      return false;
    }
    const itemsPerRow = 3;
    final firstVisibleRow =
        rowExtent <= 0 ? 0 : (metrics.pixels / rowExtent).floor();
    final visibleRowCount =
        rowExtent <= 0 ? 6 : ((metrics.viewportDimension / rowExtent).ceil() + 2);
    final startIndex =
        (firstVisibleRow * itemsPerRow).clamp(0, filtered.length).toInt();
    final endIndex = ((firstVisibleRow + visibleRowCount + 2) * itemsPerRow)
        .clamp(0, filtered.length)
        .toInt();
    _scheduleThumbnailWarmup(
      filtered,
      startIndex: startIndex,
      endIndex: endIndex,
    );
    return false;
  }

  void _maybeWarmupVisiblePage(List<EditorAssetItem> filtered) {
    if (filtered.isEmpty) {
      _knownAssetCountByTab[_activeTab] = 0;
      return;
    }
    final previousCount = _knownAssetCountByTab[_activeTab] ?? 0;
    if (previousCount == filtered.length) {
      return;
    }
    _knownAssetCountByTab[_activeTab] = filtered.length;
    final startIndex = previousCount == 0
        ? 0
        : (previousCount - 6).clamp(0, filtered.length).toInt();
    final endIndex = previousCount == 0
        ? (filtered.length < 24 ? filtered.length : 24)
        : (previousCount + 12).clamp(0, filtered.length).toInt();
    _scheduleThumbnailWarmup(
      filtered,
      startIndex: startIndex,
      endIndex: endIndex,
      immediate: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.68;
    return SizedBox(
      height: sheetHeight,
      child: Container(
        decoration: const BoxDecoration(
          color: FxPalette.panel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: FxPalette.divider, width: 1),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: FxPalette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: FxPalette.divider,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    for (final tab in _tabs)
                      Expanded(
                        child: _MediaSheetTabButton(
                          label: tab.label,
                          isActive: tab == _activeTab,
                          onTap: () {
                            setState(() {
                              _activeTab = tab;
                              _selectedAssetId = null;
                            });
                            _requestTabAssets(tab);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<List<EditorAssetItem>>(
                valueListenable: widget.assetsListenable,
                builder: (context, assets, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: widget.loadingListenable,
                    builder: (context, isLoading, __) {
                      return ValueListenableBuilder<String?>(
                        valueListenable: widget.errorListenable,
                        builder: (context, errorMessage, ___) {
                          final filtered = assets
                              .where((item) => item.tab == _activeTab)
                              .toList(growable: false);
                          EditorAssetItem? selectedAsset;
                          for (final item in filtered) {
                            if (item.id == _selectedAssetId) {
                              selectedAsset = item;
                              break;
                            }
                          }

                          return Column(
                            children: [
                              Expanded(
                                child: _buildGridBody(
                                  filtered: filtered,
                                  isLoading: isLoading,
                                  errorMessage: errorMessage,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: selectedAsset == null || isLoading
                                        ? null
                                        : () async {
                                            final asset = selectedAsset;
                                            if (asset == null) {
                                              return;
                                            }
                                            await widget.onAssetAdd(asset);
                                          },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: FxPalette.accent,
                                      foregroundColor: Colors.black,
                                      disabledBackgroundColor:
                                          FxPalette.surfaceRaised,
                                      disabledForegroundColor:
                                          FxPalette.textMuted,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      isLoading
                                          ? 'Loading...'
                                          : 'Add to timeline',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridBody({
    required List<EditorAssetItem> filtered,
    required bool isLoading,
    required String? errorMessage,
  }) {
    if (isLoading && filtered.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(FxPalette.accent),
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return _MediaSheetEmptyState(
        message: errorMessage ??
            'No ${_activeTab.label.toLowerCase()} items found on this device.',
        onRetry: () => _requestTabAssets(_activeTab),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 3;
        const horizontalInset = 20.0;
        const horizontalPadding = horizontalInset * 2;
        const crossAxisSpacing = 14.0;
        const mainAxisSpacing = 14.0;
        const childAspectRatio = 0.64;
        final tileWidth =
            (constraints.maxWidth - horizontalPadding - (crossAxisSpacing * 2)) /
                crossAxisCount;
        final tileHeight = tileWidth / childAspectRatio;
        final rowExtent = tileHeight + mainAxisSpacing;

        _maybeWarmupVisiblePage(filtered);

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis != Axis.vertical) {
              return false;
            }
            return _handleGridScroll(
              notification: notification,
              metrics: notification.metrics,
              filtered: filtered,
              rowExtent: rowExtent,
            );
          },
          child: GridView.builder(
            cacheExtent: rowExtent,
            padding: const EdgeInsets.fromLTRB(
              horizontalInset,
              8,
              horizontalInset,
              16,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.64,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final item = filtered[index];
              final isSelected = item.id == _selectedAssetId;
              return RepaintBoundary(
                key: ValueKey<String>(item.id),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : FxPalette.divider,
                      width: isSelected ? 1.6 : 1,
                    ),
                    color: FxPalette.surfaceRaised,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        setState(() {
                          _selectedAssetId = isSelected ? null : item.id;
                        });
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(17),
                              child: _MediaSheetAssetThumbnail(
                                asset: item,
                                thumbnailListenable:
                                    _thumbnailNotifierFor(item.id),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? FxPalette.accent
                                    : Colors.black.withOpacity(0.28),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.9)
                                      : Colors.white.withOpacity(0.45),
                                  width: isSelected ? 1.4 : 1,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.black,
                                      size: 18,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MediaSheetAssetThumbnail extends StatelessWidget {
  const _MediaSheetAssetThumbnail({
    required this.asset,
    required this.thumbnailListenable,
  });

  final EditorAssetItem asset;
  final ValueListenable<Uint8List?> thumbnailListenable;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Uint8List?>(
      valueListenable: thumbnailListenable,
      builder: (context, bytes, _) {
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            cacheWidth: 192,
            cacheHeight: 320,
          );
        }

        final placeholderIcon = asset.tab == EditorMediaTab.image
            ? Icons.image_outlined
            : Icons.movie_outlined;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                FxPalette.surfaceRaised,
                FxPalette.panel,
              ],
            ),
          ),
          child: Center(
            child: Icon(
              placeholderIcon,
              size: 32,
              color: Colors.white.withOpacity(0.42),
            ),
          ),
        );
      },
    );
  }
}

class _MediaSheetEmptyState extends StatelessWidget {
  const _MediaSheetEmptyState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.perm_media_rounded,
              color: FxPalette.textMuted,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FxPalette.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: FxPalette.textPrimary,
                side: const BorderSide(color: FxPalette.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaSheetTabButton extends StatelessWidget {
  const _MediaSheetTabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? FxPalette.textPrimary : FxPalette.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
