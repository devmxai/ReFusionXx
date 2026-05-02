import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('master clock current time guard script passes on current baseline', () async {
    final result = await Process.run(
      'bash',
      <String>['scripts/master_clock_current_time_guard_check.sh'],
      workingDirectory: Directory.current.path,
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(
      (result.stdout as String).contains(
        'master-clock-current-time-guard: passed',
      ),
      isTrue,
    );
  });
}
