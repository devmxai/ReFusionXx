import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

@immutable
class AnimateBrowserItem {
  const AnimateBrowserItem({
    required this.id,
    required this.label,
    required this.category,
    required this.summary,
    this.keywords = const <String>[],
  });

  final String id;
  final String label;
  final String category;
  final String summary;
  final List<String> keywords;
}

class AnimateBrowserBottomSheet extends StatefulWidget {
  const AnimateBrowserBottomSheet({
    super.key,
    required this.items,
  });

  final List<AnimateBrowserItem> items;

  static const List<AnimateBrowserItem> defaultItems = <AnimateBrowserItem>[
    AnimateBrowserItem(
      id: 'position',
      label: 'Position',
      category: 'Transform',
      summary: 'Move any layer on X and Y over time.',
      keywords: <String>['move', 'translate', 'x', 'y'],
    ),
    AnimateBrowserItem(
      id: 'scale',
      label: 'Scale',
      category: 'Transform',
      summary: 'Resize layers smoothly or with punchy motion.',
      keywords: <String>['resize', 'zoom', 'size'],
    ),
    AnimateBrowserItem(
      id: 'rotation',
      label: 'Rotation',
      category: 'Transform',
      summary: 'Rotate layers with clean angle control.',
      keywords: <String>['angle', 'spin', 'turn'],
    ),
    AnimateBrowserItem(
      id: 'anchor_point',
      label: 'Anchor Point',
      category: 'Transform',
      summary: 'Change the pivot for motion and transforms.',
      keywords: <String>['pivot', 'origin'],
    ),
    AnimateBrowserItem(
      id: 'opacity',
      label: 'Opacity',
      category: 'Visual',
      summary: 'Fade layers in, out, or between states.',
      keywords: <String>['fade', 'alpha', 'transparency'],
    ),
    AnimateBrowserItem(
      id: 'blur',
      label: 'Blur',
      category: 'Visual',
      summary: 'Add soft cinematic blur with animated strength.',
      keywords: <String>['gaussian', 'soften', 'focus'],
    ),
    AnimateBrowserItem(
      id: 'brightness',
      label: 'Brightness',
      category: 'Visual',
      summary: 'Raise or lower luminance over time.',
      keywords: <String>['light', 'exposure', 'glow'],
    ),
    AnimateBrowserItem(
      id: 'contrast',
      label: 'Contrast',
      category: 'Visual',
      summary: 'Push the image for cleaner depth and punch.',
      keywords: <String>['levels', 'tone'],
    ),
    AnimateBrowserItem(
      id: 'saturation',
      label: 'Saturation',
      category: 'Visual',
      summary: 'Control how vivid or muted the layer becomes.',
      keywords: <String>['color', 'vibrance'],
    ),
    AnimateBrowserItem(
      id: 'tint',
      label: 'Tint',
      category: 'Color',
      summary: 'Shift colors for stylized looks and grading.',
      keywords: <String>['grade', 'duotone', 'colorize'],
    ),
    AnimateBrowserItem(
      id: 'shadow',
      label: 'Shadow',
      category: 'Effects',
      summary: 'Add separation and depth behind the layer.',
      keywords: <String>['drop shadow', 'depth'],
    ),
    AnimateBrowserItem(
      id: 'glow',
      label: 'Glow',
      category: 'Effects',
      summary: 'Create radiant edges and light blooms.',
      keywords: <String>['bloom', 'shine'],
    ),
    AnimateBrowserItem(
      id: 'motion_blur',
      label: 'Motion Blur',
      category: 'Effects',
      summary: 'Add trailing blur driven by movement.',
      keywords: <String>['velocity', 'smear'],
    ),
    AnimateBrowserItem(
      id: 'warp',
      label: 'Warp',
      category: 'Distort',
      summary: 'Bend and distort layers with controlled force.',
      keywords: <String>['distort', 'bend', 'mesh'],
    ),
    AnimateBrowserItem(
      id: 'shake',
      label: 'Shake',
      category: 'Distort',
      summary: 'Inject handheld motion and impact energy.',
      keywords: <String>['jitter', 'camera shake'],
    ),
    AnimateBrowserItem(
      id: 'tracking',
      label: 'Tracking',
      category: 'Text',
      summary: 'Animate text spacing for elegant motion.',
      keywords: <String>['letter spacing', 'text'],
    ),
    AnimateBrowserItem(
      id: 'weight',
      label: 'Weight',
      category: 'Text',
      summary: 'Change font weight as part of the animation.',
      keywords: <String>['font', 'bold', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_warp',
      label: 'Text Warp',
      category: 'Text',
      summary: 'Deform text for expressive motion design.',
      keywords: <String>['bend', 'curve', 'text'],
    ),
    AnimateBrowserItem(
      id: 'adjustment_blur',
      label: 'Adjustment Blur',
      category: 'Adjustment',
      summary: 'Apply blur from an adjustment-style control row.',
      keywords: <String>['adjustment layer', 'gaussian'],
    ),
    AnimateBrowserItem(
      id: 'color_grade',
      label: 'Color Grade',
      category: 'Adjustment',
      summary: 'Mock color grading controls for the layer stack.',
      keywords: <String>['grade', 'adjustment', 'look'],
    ),
  ];

  @override
  State<AnimateBrowserBottomSheet> createState() =>
      _AnimateBrowserBottomSheetState();
}

class ScopedLayerAnimateBottomSheet extends StatefulWidget {
  const ScopedLayerAnimateBottomSheet({
    super.key,
    required this.items,
  });

  final List<AnimateBrowserItem> items;

  static const List<AnimateBrowserItem> defaultItems = <AnimateBrowserItem>[
    AnimateBrowserItem(
      id: 'opacity',
      label: 'Opacity',
      category: 'Animate',
      summary: 'Animate layer transparency with keyframes.',
      keywords: <String>['fade', 'alpha', 'transparency'],
    ),
    AnimateBrowserItem(
      id: 'position',
      label: 'Position',
      category: 'Animate',
      summary: 'Animate layer movement on X and Y.',
      keywords: <String>['move', 'x', 'y', 'translate'],
    ),
    AnimateBrowserItem(
      id: 'scale',
      label: 'Scale',
      category: 'Animate',
      summary: 'Animate layer size on X and Y.',
      keywords: <String>['scale', 'size', 'zoom', 'resize'],
    ),
    AnimateBrowserItem(
      id: 'rotation',
      label: 'Rotation',
      category: 'Animate',
      summary: 'Animate layer angle over time.',
      keywords: <String>['rotate', 'angle', 'spin', 'turn'],
    ),
  ];

  @override
  State<ScopedLayerAnimateBottomSheet> createState() =>
      _ScopedLayerAnimateBottomSheetState();
}

class _ScopedLayerAnimateBottomSheetState
    extends State<ScopedLayerAnimateBottomSheet> {
  late final TextEditingController _searchController;
  late final FocusNode _focusNode;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<AnimateBrowserItem> get _filteredItems {
    final normalizedQuery = _query.trim().toLowerCase();
    final items = List<AnimateBrowserItem>.from(widget.items);
    if (normalizedQuery.isEmpty) {
      return items;
    }
    final scoredItems = <({AnimateBrowserItem item, int score})>[];
    for (final item in items) {
      final label = item.label.toLowerCase();
      final category = item.category.toLowerCase();
      final summary = item.summary.toLowerCase();
      final keywords = item.keywords.map((keyword) => keyword.toLowerCase());
      int? score;
      if (label.startsWith(normalizedQuery)) {
        score = 0;
      } else if (label.contains(normalizedQuery)) {
        score = 1;
      } else if (category.startsWith(normalizedQuery)) {
        score = 2;
      } else if (keywords
          .any((keyword) => keyword.startsWith(normalizedQuery))) {
        score = 3;
      } else if (keywords.any((keyword) => keyword.contains(normalizedQuery))) {
        score = 4;
      } else if (summary.contains(normalizedQuery)) {
        score = 5;
      }
      if (score != null) {
        scoredItems.add((item: item, score: score));
      }
    }
    scoredItems.sort((left, right) {
      final scoreCompare = left.score.compareTo(right.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return left.item.label.compareTo(right.item.label);
    });
    return scoredItems.map((entry) => entry.item).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final sheetHeight = MediaQuery.of(context).size.height * 0.68;
    final items = _filteredItems;
    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: SizedBox(
        height: sheetHeight,
        child: Container(
          decoration: const BoxDecoration(
            color: FxPalette.panel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: FxPalette.divider, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: _AnimateSearchField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? Padding(
                          padding: EdgeInsets.fromLTRB(
                            14,
                            16,
                            14,
                            (safeBottom > 0 ? safeBottom : 12) + 6,
                          ),
                          child: const _AnimateEmptyState(),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            (safeBottom > 0 ? safeBottom : 12) + 8,
                          ),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _AnimateBrowserItemTile(
                              item: item,
                              query: _query,
                              onAdd: () => Navigator.of(context).pop(item),
                            );
                          },
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemCount: items.length,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimateBrowserBottomSheetState extends State<AnimateBrowserBottomSheet> {
  late final TextEditingController _searchController;
  late final FocusNode _focusNode;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<AnimateBrowserItem> get _filteredItems {
    final normalizedQuery = _query.trim().toLowerCase();
    final items = List<AnimateBrowserItem>.from(widget.items);
    if (normalizedQuery.isEmpty) {
      items.sort(
        (left, right) => left.category == right.category
            ? left.label.compareTo(right.label)
            : left.category.compareTo(right.category),
      );
      return items;
    }

    final scoredItems = <({AnimateBrowserItem item, int score})>[];
    for (final item in items) {
      final label = item.label.toLowerCase();
      final category = item.category.toLowerCase();
      final summary = item.summary.toLowerCase();
      final keywords = item.keywords.map((keyword) => keyword.toLowerCase());
      int? score;
      if (label.startsWith(normalizedQuery)) {
        score = 0;
      } else if (label.contains(normalizedQuery)) {
        score = 1;
      } else if (category.startsWith(normalizedQuery)) {
        score = 2;
      } else if (keywords
          .any((keyword) => keyword.startsWith(normalizedQuery))) {
        score = 3;
      } else if (keywords.any((keyword) => keyword.contains(normalizedQuery))) {
        score = 4;
      } else if (summary.contains(normalizedQuery)) {
        score = 5;
      }
      if (score != null) {
        scoredItems.add((item: item, score: score));
      }
    }

    scoredItems.sort((left, right) {
      final scoreCompare = left.score.compareTo(right.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      final categoryCompare = left.item.category.compareTo(right.item.category);
      if (categoryCompare != 0) {
        return categoryCompare;
      }
      return left.item.label.compareTo(right.item.label);
    });
    return scoredItems.map((entry) => entry.item).toList(growable: false);
  }

  List<String> get _suggestedCategories {
    final categories = <String>{};
    for (final item in widget.items) {
      categories.add(item.category);
    }
    return categories.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final items = _filteredItems;
    final sheetHeight =
        (MediaQuery.sizeOf(context).height * 0.47).clamp(360.0, 470.0);

    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: sheetHeight,
            decoration: BoxDecoration(
              color: FxPalette.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              border: Border.all(color: FxPalette.divider, width: 1),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: FxPalette.textFaint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: _AnimateSearchField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                    ),
                  ),
                  if (_query.trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: SizedBox(
                        height: 32,
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (context, index) {
                            final category = _suggestedCategories[index];
                            return _CategoryChip(
                              label: category,
                              onTap: () {
                                _searchController.text = category;
                                _searchController.selection =
                                    TextSelection.collapsed(
                                  offset: category.length,
                                );
                                setState(() {
                                  _query = category;
                                });
                              },
                            );
                          },
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemCount: _suggestedCategories.length,
                        ),
                      ),
                    ),
                  Expanded(
                    child: items.isEmpty
                        ? Padding(
                            padding: EdgeInsets.fromLTRB(
                              14,
                              16,
                              14,
                              (safeBottom > 0 ? safeBottom : 12) + 6,
                            ),
                            child: const _AnimateEmptyState(),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              14,
                              0,
                              14,
                              (safeBottom > 0 ? safeBottom : 12) + 6,
                            ),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return _AnimateBrowserItemTile(
                                item: item,
                                query: _query,
                                onAdd: () => Navigator.of(context).pop(item),
                              );
                            },
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemCount: items.length,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimateSearchField extends StatelessWidget {
  const _AnimateSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        scrollPadding: EdgeInsets.zero,
        style: const TextStyle(
          color: FxPalette.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withOpacity(0.52),
            size: 22,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  splashRadius: 18,
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withOpacity(0.44),
                    size: 20,
                  ),
                ),
          hintText: 'Search animation, effect, or property',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.72),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AnimateBrowserItemTile extends StatelessWidget {
  const _AnimateBrowserItemTile({
    required this.item,
    required this.query,
    required this.onAdd,
  });

  final AnimateBrowserItem item;
  final String query;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onAdd,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HighlightedMatchText(
                        text: item.label,
                        query: query,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.62),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _AddItemButton(onTap: onAdd),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddItemButton extends StatelessWidget {
  const _AddItemButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: FxPalette.accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: FxPalette.accent.withOpacity(0.32),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: FxPalette.accent.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: FxPalette.textPrimary,
          size: 20,
        ),
      ),
    );
  }
}

class _HighlightedMatchText extends StatelessWidget {
  const _HighlightedMatchText({
    required this.text,
    required this.query,
  });

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedText = text.toLowerCase();
    final matchIndex =
        normalizedQuery.isEmpty ? -1 : normalizedText.indexOf(normalizedQuery);
    if (matchIndex < 0 || normalizedQuery.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          color: FxPalette.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    final before = text.substring(0, matchIndex);
    final match =
        text.substring(matchIndex, matchIndex + normalizedQuery.length);
    final after = text.substring(matchIndex + normalizedQuery.length);
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: FxPalette.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: const TextStyle(
              color: FxPalette.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}

class _AnimateEmptyState extends StatelessWidget {
  const _AnimateEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.auto_awesome_motion_rounded,
                color: Colors.white.withOpacity(0.56),
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No matching animation found',
              style: TextStyle(
                color: FxPalette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try another keyword like blur, scale, opacity, warp, or adjustment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
