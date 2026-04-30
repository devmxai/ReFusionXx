import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/timeline_mock_models.dart';

enum TransitionBrowserAction {
  applyPreset,
  openManual,
  openAi,
}

class TransitionBrowserResult {
  const TransitionBrowserResult({
    required this.action,
    required this.preset,
  });

  final TransitionBrowserAction action;
  final TimelineTransitionPreset preset;
}

enum _TransitionBrowserPage {
  menu,
  presets,
}

class TransitionBrowserBottomSheet extends StatefulWidget {
  const TransitionBrowserBottomSheet({
    super.key,
    this.presets = const <TimelineTransitionPreset>[
      TimelineTransitionPreset.crossDissolve,
      TimelineTransitionPreset.fadeBlack,
      TimelineTransitionPreset.zoomInCamera,
    ],
  });

  final List<TimelineTransitionPreset> presets;

  @override
  State<TransitionBrowserBottomSheet> createState() =>
      _TransitionBrowserBottomSheetState();
}

class _TransitionBrowserBottomSheetState
    extends State<TransitionBrowserBottomSheet> {
  late final TextEditingController _searchController;
  late final FocusNode _focusNode;
  _TransitionBrowserPage _page = _TransitionBrowserPage.menu;
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

  List<TimelineTransitionPreset> get _filteredPresets {
    final normalized = _query.trim().toLowerCase();
    final presets = List<TimelineTransitionPreset>.from(widget.presets);
    if (normalized.isEmpty) {
      return presets;
    }
    return presets.where((preset) {
      final label = preset.label.toLowerCase();
      final summary = preset.summary.toLowerCase();
      return label.contains(normalized) || summary.contains(normalized);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = _page == _TransitionBrowserPage.menu
        ? (screenHeight * 0.50).clamp(360.0, 520.0).toDouble()
        : (screenHeight * 0.58).clamp(440.0, 640.0).toDouble();
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: sheetHeight,
          padding: EdgeInsets.only(bottom: safeBottom),
          decoration: const BoxDecoration(
            color: FxPalette.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: _page == _TransitionBrowserPage.menu
              ? _buildMenu(context)
              : _buildPresetPicker(context),
        ),
      ),
    );
  }

  Widget _buildChrome({
    required List<Widget> children,
  }) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: FxPalette.textFaint,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildMenu(BuildContext context) {
    return _buildChrome(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Transition Bridge',
              style: TextStyle(
                color: FxPalette.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _TransitionModeCard(
                  title: 'Preset',
                  summary:
                      'Choose an engine-backed transition that keeps playback and scrub on the main timeline.',
                  icon: Icons.video_settings_rounded,
                  emphasized: true,
                  onTap: () => setState(() {
                    _page = _TransitionBrowserPage.presets;
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _ManualTransitionCard(
                  onTap: () => Navigator.of(context).pop(
                    const TransitionBrowserResult(
                      action: TransitionBrowserAction.openManual,
                      preset: TimelineTransitionPreset.manual,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: _AiTransitionCard(
                  onTap: () => Navigator.of(context).pop(
                    const TransitionBrowserResult(
                      action: TransitionBrowserAction.openAi,
                      preset: TimelineTransitionPreset.aiGenerated,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetPicker(BuildContext context) {
    return _buildChrome(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() {
                  _page = _TransitionBrowserPage.menu;
                }),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: FxPalette.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Preset Transitions',
                  style: TextStyle(
                    color: FxPalette.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: _buildSearchField(),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            itemCount: _filteredPresets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final preset = _filteredPresets[index];
              return _TransitionPresetCard(
                preset: preset,
                onTap: () => Navigator.of(context).pop(
                  TransitionBrowserResult(
                    action: TransitionBrowserAction.applyPreset,
                    preset: preset,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FxPalette.dividerSoft,
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        onChanged: (value) => setState(() {
          _query = value;
        }),
        style: const TextStyle(
          color: FxPalette.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Search preset',
          hintStyle: TextStyle(
            color: FxPalette.textMuted.withOpacity(0.88),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: FxPalette.textMuted,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: FxPalette.textMuted,
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class _TransitionModeCard extends StatelessWidget {
  const _TransitionModeCard({
    required this.title,
    required this.summary,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  final String title;
  final String summary;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: FxPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: emphasized
                ? FxPalette.accent.withOpacity(0.36)
                : FxPalette.dividerSoft,
            width: 1,
          ),
          gradient: emphasized
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FxPalette.accent.withOpacity(0.12),
                    Colors.white.withOpacity(0.03),
                  ],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: FxPalette.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FxPalette.accent.withOpacity(0.28),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: FxPalette.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: FxPalette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      summary,
                      style: TextStyle(
                        color: FxPalette.textMuted.withOpacity(0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: FxPalette.textPrimary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualTransitionCard extends StatelessWidget {
  const _ManualTransitionCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: FxPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: FxPalette.accent.withOpacity(0.32),
            width: 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FxPalette.accent.withOpacity(0.10),
              Colors.white.withOpacity(0.03),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: FxPalette.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FxPalette.accent.withOpacity(0.28),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: FxPalette.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manual',
                      style: TextStyle(
                        color: FxPalette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Open the focused seam timeline and start editing the transition lanes directly.',
                      style: TextStyle(
                        color: FxPalette.textMuted.withOpacity(0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: FxPalette.textPrimary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransitionPresetCard extends StatelessWidget {
  const _TransitionPresetCard({
    required this.preset,
    required this.onTap,
  });

  final TimelineTransitionPreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: FxPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: FxPalette.dividerSoft,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: Icon(
                  switch (preset) {
                    TimelineTransitionPreset.manual => Icons.tune_rounded,
                    TimelineTransitionPreset.crossDissolve =>
                      Icons.blur_linear_rounded,
                    TimelineTransitionPreset.fadeBlack =>
                      Icons.gradient_rounded,
                    TimelineTransitionPreset.zoomInCamera =>
                      Icons.center_focus_strong_rounded,
                    TimelineTransitionPreset.aiGenerated =>
                      Icons.auto_awesome_rounded,
                  },
                  color: Colors.white.withOpacity(0.88),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.label,
                      style: const TextStyle(
                        color: FxPalette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preset.summary,
                      style: TextStyle(
                        color: FxPalette.textMuted.withOpacity(0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: FxPalette.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: FxPalette.accent.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: FxPalette.accent,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiTransitionCard extends StatelessWidget {
  const _AiTransitionCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: FxPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: FxPalette.accent.withOpacity(0.28),
            width: 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FxPalette.accent.withOpacity(0.09),
              Colors.white.withOpacity(0.02),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: FxPalette.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FxPalette.accent.withOpacity(0.28),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: FxPalette.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Transition',
                      style: TextStyle(
                        color: FxPalette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Generate a seam draft from clip A last frame to clip B first frame.',
                      style: TextStyle(
                        color: FxPalette.textMuted.withOpacity(0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: FxPalette.textPrimary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
