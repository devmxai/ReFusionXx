import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/ai_transition_models.dart';

class AiTransitionBottomSheetResult {
  const AiTransitionBottomSheetResult({
    required this.draft,
  });

  final AiTransitionDraftData draft;
}

class AiTransitionBottomSheet extends StatefulWidget {
  const AiTransitionBottomSheet({
    super.key,
    required this.leftClipLabel,
    required this.rightClipLabel,
    this.leftFrameBytes,
    this.rightFrameBytes,
    this.initialDraft,
  });

  final String leftClipLabel;
  final String rightClipLabel;
  final Uint8List? leftFrameBytes;
  final Uint8List? rightFrameBytes;
  final AiTransitionDraftData? initialDraft;

  @override
  State<AiTransitionBottomSheet> createState() =>
      _AiTransitionBottomSheetState();
}

class _AiTransitionBottomSheetState extends State<AiTransitionBottomSheet> {
  late final TextEditingController _promptController;
  late AiTransitionModel _model;
  late int _durationSeconds;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDraft;
    _model = initial?.model ?? AiTransitionModel.grokImagineImageToVideo;
    _durationSeconds = _clampDuration(
      initial?.durationSeconds ?? _model.defaultDurationSeconds,
      model: _model,
    );
    _promptController = TextEditingController(
      text: initial?.prompt ??
          'Create a smooth cinematic transition from image one to image two. Begin faithfully on the first frame, end faithfully on the second frame, keep the subject consistent, and make the bridge feel premium and elegant.',
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  int _clampDuration(int value, {required AiTransitionModel model}) {
    return value.clamp(
      model.minDurationSeconds,
      model.maxDurationSeconds,
    );
  }

  void _selectModel(AiTransitionModel model) {
    setState(() {
      _model = model;
      _durationSeconds = _clampDuration(_durationSeconds, model: model);
    });
  }

  void _submitDraft() {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      AiTransitionBottomSheetResult(
        draft: AiTransitionDraftData(
          model: _model,
          prompt: prompt,
          durationSeconds: _durationSeconds,
          soundEnabled: false,
          status: AiTransitionJobStatus.waitingForBackend,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final minDuration = _model.minDurationSeconds;
    final maxDuration = _model.maxDurationSeconds;
    final durationValue = _durationSeconds.toDouble();
    final divisions = maxDuration - minDuration;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.72,
          ),
          padding: EdgeInsets.only(bottom: safeBottom),
          decoration: const BoxDecoration(
            color: FxPalette.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 14),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _AiPromptCard(
                      controller: _promptController,
                    ),
                    const SizedBox(height: 14),
                    _AiTransitionSection(
                      label: 'Model',
                      child: Column(
                        children: AiTransitionModel.values.map((model) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _AiModelTile(
                              model: model,
                              isActive: model == _model,
                              onTap: () => _selectModel(model),
                            ),
                          );
                        }).toList(growable: false),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _AiTransitionSection(
                      label: 'Duration',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: FxPalette.accent,
                                    inactiveTrackColor:
                                        FxPalette.accent.withOpacity(0.18),
                                    thumbColor: Colors.white,
                                    overlayColor:
                                        FxPalette.accent.withOpacity(0.12),
                                  ),
                                  child: Slider(
                                    min: minDuration.toDouble(),
                                    max: maxDuration.toDouble(),
                                    divisions:
                                        divisions <= 0 ? null : divisions,
                                    value: durationValue,
                                    onChanged: (value) {
                                      setState(() {
                                        _durationSeconds = value.round();
                                      });
                                    },
                                  ),
                                ),
                              ),
                              Container(
                                width: 64,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Text(
                                  '${_durationSeconds}s',
                                  style: const TextStyle(
                                    color: FxPalette.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Range ${minDuration}s - ${maxDuration}s for ${_model.label}.',
                            style: TextStyle(
                              color: FxPalette.textMuted.withOpacity(0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _AiTransitionSection(
                      label: 'Boundary Frames',
                      child: Row(
                        children: [
                          Expanded(
                            child: _FrameEndpointTile(
                              label: 'A last frame',
                              value: widget.leftClipLabel,
                              bytes: widget.leftFrameBytes,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _FrameEndpointTile(
                              label: 'B first frame',
                              value: widget.rightClipLabel,
                              bytes: widget.rightFrameBytes,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: ElevatedButton(
                  onPressed: _submitDraft,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FxPalette.accent,
                    foregroundColor: FxPalette.background,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Generate',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiPromptCard extends StatelessWidget {
  const _AiPromptCard({
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FxPalette.dividerSoft, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: TextField(
          controller: controller,
          minLines: 5,
          maxLines: 7,
          maxLength: 2500,
          style: const TextStyle(
            color: FxPalette.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
          decoration: InputDecoration(
            counterStyle: TextStyle(
              color: FxPalette.textMuted.withOpacity(0.76),
              fontSize: 11,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            hintText:
                'Describe the cinematic motion between the last frame of A and the first frame of B.',
            hintStyle: TextStyle(
              color: FxPalette.textMuted.withOpacity(0.72),
              fontSize: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: FxPalette.accent.withOpacity(0.65),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiTransitionSection extends StatelessWidget {
  const _AiTransitionSection({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FxPalette.dividerSoft, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: FxPalette.textMuted.withOpacity(0.88),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _FrameEndpointTile extends StatelessWidget {
  const _FrameEndpointTile({
    required this.label,
    required this.value,
    this.bytes,
  });

  final String label;
  final String value;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: FxPalette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: bytes == null
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              FxPalette.surface,
                              FxPalette.surfaceRaised,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.photo_outlined,
                            color: FxPalette.textMuted,
                            size: 22,
                          ),
                        ),
                      )
                    : Image.memory(
                        bytes!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FxPalette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiModelTile extends StatelessWidget {
  const _AiModelTile({
    required this.model,
    required this.isActive,
    required this.onTap,
  });

  final AiTransitionModel model;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Ink(
        decoration: BoxDecoration(
          color: isActive
              ? FxPalette.accent.withOpacity(0.13)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isActive
                ? FxPalette.accent.withOpacity(0.58)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(
                model == AiTransitionModel.grokImagineImageToVideo
                    ? Icons.auto_awesome_motion_rounded
                    : model == AiTransitionModel.kling3StandardSilent
                        ? Icons.movie_filter_rounded
                        : Icons.auto_fix_high_rounded,
                color: isActive ? FxPalette.accent : FxPalette.textMuted,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.label,
                      style: const TextStyle(
                        color: FxPalette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      model.summary,
                      style: TextStyle(
                        color: FxPalette.textMuted.withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                const Icon(
                  Icons.check_circle_rounded,
                  color: FxPalette.accent,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
