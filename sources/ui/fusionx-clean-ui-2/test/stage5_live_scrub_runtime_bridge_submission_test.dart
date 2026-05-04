import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/core/engine/stage5_native_transport_controller.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_descriptor_models.dart';

void main() {
  test('marks proof matched when native accepts and no blockers', () {
    const baseProof = RendererPresentationProof(
      requestedRootTimeMs: 1200,
      requestedFrameIndex: 36,
      requestedCommitFrameNumber: 91,
      requestedSourceIds: <String>['clip-a'],
      requestId: 'req-1',
      sourceRevision: 'msr:abc',
      renderGraphRevision: 'mrg:def',
      rendererMode: 'liveScrub',
    );
    final submission = parseLiveScrubRuntimeBridgeSubmission(
      baseProof: baseProof,
      response: <String, dynamic>{
        'accepted': true,
        'nativeReceivedAtMs': 2000,
        'surfaceId': 'stage5-surface',
        'requestId': 'req-1',
        'requestedRootTimeMs': 1200,
      },
    );
    expect(submission.accepted, isTrue);
    expect(submission.proof.nativePresentationAck, isTrue);
    expect(
      submission.proof.matchState,
      RendererPresentationMatchState.matched,
    );
    expect(
      submission.proof.presentedRootTimeMs,
      baseProof.requestedRootTimeMs,
    );
    expect(submission.proof.presentationTimestampUs, 2000000);
    expect(submission.proof.surfaceId, 'stage5-surface');
  });

  test('marks proof blocked when native accepts but blockers exist', () {
    const baseProof = RendererPresentationProof(
      requestedRootTimeMs: 900,
      requestedFrameIndex: 27,
      requestedCommitFrameNumber: 77,
      requestedSourceIds: <String>['clip-a'],
      requestId: 'req-2',
      blockers: <String>['missing_source_window:clip-a'],
    );
    final submission = parseLiveScrubRuntimeBridgeSubmission(
      baseProof: baseProof,
      response: <String, dynamic>{
        'accepted': true,
      },
    );
    expect(submission.accepted, isTrue);
    expect(
      submission.proof.matchState,
      RendererPresentationMatchState.blocked,
    );
    expect(
      submission.proof.matchReason,
      'runtime_bridge_snapshot_contains_blockers',
    );
  });

  test('marks proof blocked when native rejects submission', () {
    const baseProof = RendererPresentationProof(
      requestedRootTimeMs: 500,
      requestedFrameIndex: 15,
      requestedCommitFrameNumber: 41,
      requestId: 'req-3',
    );
    final submission = parseLiveScrubRuntimeBridgeSubmission(
      baseProof: baseProof,
      response: <String, dynamic>{
        'accepted': false,
      },
    );
    expect(submission.accepted, isFalse);
    expect(submission.proof.nativePresentationAck, isFalse);
    expect(
      submission.proof.matchState,
      RendererPresentationMatchState.blocked,
    );
    expect(
      submission.proof.matchReason,
      'native_rejected_runtime_bridge_snapshot',
    );
  });

  test('marks proof mismatched when native echoes different request id', () {
    const baseProof = RendererPresentationProof(
      requestedRootTimeMs: 1400,
      requestedFrameIndex: 42,
      requestedCommitFrameNumber: 100,
      requestId: 'req-4',
    );
    final submission = parseLiveScrubRuntimeBridgeSubmission(
      baseProof: baseProof,
      response: <String, dynamic>{
        'accepted': true,
        'requestId': 'req-other',
        'requestedRootTimeMs': 1400,
      },
    );
    expect(submission.accepted, isTrue);
    expect(
      submission.proof.matchState,
      RendererPresentationMatchState.mismatched,
    );
    expect(
      submission.proof.matchReason,
      'native_ack_request_id_mismatch',
    );
  });

  test(
      'marks proof mismatched when native echoes different requested root time',
      () {
    const baseProof = RendererPresentationProof(
      requestedRootTimeMs: 1600,
      requestedFrameIndex: 48,
      requestedCommitFrameNumber: 101,
      requestId: 'req-5',
    );
    final submission = parseLiveScrubRuntimeBridgeSubmission(
      baseProof: baseProof,
      response: <String, dynamic>{
        'accepted': true,
        'requestId': 'req-5',
        'requestedRootTimeMs': 1700,
      },
    );
    expect(submission.accepted, isTrue);
    expect(
      submission.proof.matchState,
      RendererPresentationMatchState.mismatched,
    );
    expect(
      submission.proof.matchReason,
      'native_ack_requested_root_time_mismatch',
    );
    expect(submission.proof.presentedRootTimeMs, 1700);
  });
}
