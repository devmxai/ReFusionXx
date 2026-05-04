import 'package:flutter/foundation.dart';

import 'master_live_scrub_descriptor_models.dart';

enum MasterRendererAdapterMode {
  preview,
  liveScrub,
  playback,
  export,
}

@immutable
class MasterRendererFrameResult {
  MasterRendererFrameResult({
    required this.mode,
    required this.proof,
    List<String> blockers = const <String>[],
    List<String> diagnostics = const <String>[],
  })  : blockers = List.unmodifiable(blockers),
        diagnostics = List.unmodifiable(diagnostics);

  final MasterRendererAdapterMode mode;
  final RendererPresentationProof proof;
  final List<String> blockers;
  final List<String> diagnostics;

  bool get canPresentTruthfully {
    return blockers.isEmpty &&
        proof.matchState == RendererPresentationMatchState.matched;
  }
}
