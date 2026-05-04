import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screenFile = File(
    'lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart',
  );

  test('master evaluation path uses universal evaluation service', () async {
    final source = await screenFile.readAsString();
    expect(
      source.contains('MasterFrameEvaluation? _masterFrameEvaluationForMode('),
      isFalse,
    );
    final methodStart =
        source.indexOf('MasterFrameEvaluation _masterFrameEvaluationForMode(');
    expect(methodStart, isNonNegative);
    final methodEnd = source.indexOf(
      'String _liveScrubRuntimeBridgeSubmissionKey({',
      methodStart,
    );
    expect(methodEnd, greaterThan(methodStart));
    final body = source.substring(methodStart, methodEnd);

    expect(body.contains('_evaluateUniversalMasterFrameForMode('), isTrue);
    expect(
        body.contains('_masterFrameEvaluationReadAdapter.evaluate('), isFalse);
  });

  test('transition runtime bridge does not drop evaluated channels', () async {
    final source = await screenFile.readAsString();
    final methodStart = source.indexOf(
      'LiveScrubVisualProgram _liveScrubVisualProgramForTransitionRuntimeBridge({',
    );
    expect(methodStart, isNonNegative);
    final methodEnd = source.indexOf(
      'LiveScrubVisualProgram? _manualTransitionLiveScrubProgram({',
      methodStart,
    );
    expect(methodEnd, greaterThan(methodStart));
    final body = source.substring(methodStart, methodEnd);

    expect(
      body.contains(
          'evaluatedChannels: const <MasterEvaluatedPropertyValue>[]'),
      isFalse,
    );
    expect(
      body.contains('channels: const <MotionPropertyChannelModel>[]'),
      isFalse,
    );
    expect(body.contains('blockers: const <String>[]'), isFalse);
    expect(body.contains('evaluatedChannels: evaluation.evaluatedChannels'),
        isTrue);
    expect(body.contains('_evaluateUniversalMasterFrameForMode('), isFalse);
  });

  test('manual transition runtime bridge preserves effect parameters',
      () async {
    final source = await screenFile.readAsString();
    final methodStart = source.indexOf(
      'LiveScrubVisualProgram? _manualTransitionLiveScrubProgram({',
    );
    expect(methodStart, isNonNegative);
    final methodEnd = source.indexOf(
      'Set<String> _activeManualTransitionSourceIdsForTime({',
      methodStart,
    );
    expect(methodEnd, greaterThan(methodStart));
    final body = source.substring(methodStart, methodEnd);

    expect(
        body.contains('effectParameters: evaluation.effectParameters'), isTrue);
  });
}
