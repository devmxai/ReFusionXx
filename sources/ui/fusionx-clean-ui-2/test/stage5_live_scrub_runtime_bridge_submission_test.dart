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
    expect(submission.isRenderableMatch, isTrue);
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
      sourceRevision: 'msr:req-2',
      renderGraphRevision: 'mrg:req-2',
      rendererMode: 'liveScrub',
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
      requestedSourceIds: <String>[],
      requestId: 'req-3',
      sourceRevision: 'msr:req-3',
      renderGraphRevision: 'mrg:req-3',
      rendererMode: 'liveScrub',
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

  test('captures native rejection reason when provided', () {
    const baseProof = RendererPresentationProof(
      requestedRootTimeMs: 510,
      requestedFrameIndex: 16,
      requestedCommitFrameNumber: 42,
      requestedSourceIds: <String>[],
      requestId: 'req-3b',
      sourceRevision: 'msr:req-3b',
      renderGraphRevision: 'mrg:req-3b',
      rendererMode: 'liveScrub',
    );
    final submission = parseLiveScrubRuntimeBridgeSubmission(
      baseProof: baseProof,
      response: <String, dynamic>{
        'accepted': false,
        'rejectionReason': 'missing_request_id',
      },
    );
    expect(submission.accepted, isFalse);
    expect(
      submission.proof.matchReason,
      'native_rejected_runtime_bridge_snapshot:missing_request_id',
    );
  });

  test('marks proof mismatched when native echoes different request id', () {
    const baseProof = RendererPresentationProof(
      requestedRootTimeMs: 1400,
      requestedFrameIndex: 42,
      requestedCommitFrameNumber: 100,
      requestedSourceIds: <String>['clip-a'],
      requestId: 'req-4',
      sourceRevision: 'msr:req-4',
      renderGraphRevision: 'mrg:req-4',
      rendererMode: 'liveScrub',
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
    expect(submission.isRenderableMatch, isFalse);
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
      requestedSourceIds: <String>['clip-a', 'clip-b'],
      requestId: 'req-5',
      sourceRevision: 'msr:req-5',
      renderGraphRevision: 'mrg:req-5',
      rendererMode: 'liveScrub',
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

  test('marks proof mismatched when native reports descriptor count mismatch',
      () {
    const baseProof = RendererPresentationProof(
      requestedRootTimeMs: 1800,
      requestedFrameIndex: 54,
      requestedCommitFrameNumber: 103,
      requestedSourceIds: <String>['clip-a', 'clip-b'],
      requestId: 'req-6',
      sourceRevision: 'msr:req-6',
      renderGraphRevision: 'mrg:req-6',
      rendererMode: 'liveScrub',
    );
    final submission = parseLiveScrubRuntimeBridgeSubmission(
      baseProof: baseProof,
      response: <String, dynamic>{
        'accepted': true,
        'requestId': 'req-6',
        'requestedRootTimeMs': 1800,
        'descriptorCount': 1,
      },
    );
    expect(submission.accepted, isTrue);
    expect(
      submission.proof.matchState,
      RendererPresentationMatchState.mismatched,
    );
    expect(
      submission.proof.matchReason,
      'native_ack_descriptor_count_mismatch',
    );
  });

  test('marks proof mismatched when native reports blocker count mismatch', () {
    const baseProof = RendererPresentationProof(
      requestedRootTimeMs: 1900,
      requestedFrameIndex: 57,
      requestedCommitFrameNumber: 104,
      requestedSourceIds: <String>['clip-a'],
      blockers: <String>['missing_source_window:clip-a'],
      requestId: 'req-7',
      sourceRevision: 'msr:req-7',
      renderGraphRevision: 'mrg:req-7',
      rendererMode: 'liveScrub',
    );
    final submission = parseLiveScrubRuntimeBridgeSubmission(
      baseProof: baseProof,
      response: <String, dynamic>{
        'accepted': true,
        'requestId': 'req-7',
        'requestedRootTimeMs': 1900,
        'blockerCount': 0,
      },
    );
    expect(submission.accepted, isTrue);
    expect(
      submission.proof.matchState,
      RendererPresentationMatchState.mismatched,
    );
    expect(
      submission.proof.matchReason,
      'native_ack_blocker_count_mismatch',
    );
  });

  test('reconciles proof with native snapshot as verified match', () {
    const proof = RendererPresentationProof(
      requestedRootTimeMs: 2000,
      requestedFrameIndex: 60,
      requestedCommitFrameNumber: 110,
      requestedSourceIds: <String>['clip-a', 'clip-b'],
      requestId: 'req-snapshot-ok',
      sourceRevision: 'msr:req-snapshot-ok',
      renderGraphRevision: 'mrg:req-snapshot-ok',
      rendererMode: 'liveScrub',
      nativePresentationAck: true,
      matchState: RendererPresentationMatchState.matched,
      matchReason: 'native_runtime_bridge_snapshot_acknowledged',
    );
    final reconciled = reconcileRuntimeBridgeProofWithNativeSnapshot(
      proof: proof,
      snapshot: <String, dynamic>{
        'requestId': 'req-snapshot-ok',
        'timelinePositionMs': 2000,
        'blockerCount': 0,
        'nativeReceivedAtMs': 1234,
        'surfaceId': 'surface-1',
      },
    );
    expect(reconciled.matchState, RendererPresentationMatchState.matched);
    expect(reconciled.matchReason, 'native_runtime_bridge_snapshot_verified');
    expect(reconciled.presentedRootTimeMs, 2000);
    expect(reconciled.presentationTimestampUs, 1234000);
    expect(reconciled.surfaceId, 'surface-1');
  });

  test('reconcile marks mismatch when snapshot timeline differs', () {
    const proof = RendererPresentationProof(
      requestedRootTimeMs: 3000,
      requestedFrameIndex: 90,
      requestedCommitFrameNumber: 120,
      requestedSourceIds: <String>[],
      requestId: 'req-snapshot-mismatch',
      sourceRevision: 'msr:req-snapshot-mismatch',
      renderGraphRevision: 'mrg:req-snapshot-mismatch',
      rendererMode: 'liveScrub',
      nativePresentationAck: true,
    );
    final reconciled = reconcileRuntimeBridgeProofWithNativeSnapshot(
      proof: proof,
      snapshot: <String, dynamic>{
        'requestId': 'req-snapshot-mismatch',
        'timelinePositionMs': 3100,
        'blockerCount': 0,
      },
    );
    expect(reconciled.matchState, RendererPresentationMatchState.mismatched);
    expect(
      reconciled.matchReason,
      'native_snapshot_timeline_position_mismatch',
    );
  });
}
