import 'dart:io';

const List<String> protectedRuntimePaths = <String>[
  'android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TimelineScrubPlatformView.kt',
  'android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5NativeScrubEngine.kt',
  'android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5SurfaceScrubDecoder.kt',
  'android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubOverlayTextureView.kt',
  'android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5PreviewPlatformView.kt',
  'android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt',
  'lib/core/engine/stage5_native_transport_controller.dart',
  'lib/features/editor/presentation/widgets/native_timeline_scrub_surface.dart',
  'lib/features/editor/presentation/widgets/timeline_panel.dart',
  'lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart',
];

Future<void> main(List<String> args) async {
  if (args.contains('--print-protected')) {
    stdout.writeln('Protected timeline runtime paths:');
    for (final path in protectedRuntimePaths) {
      stdout.writeln('- $path');
    }
    return;
  }

  final changedFiles = await _changedFiles(args);
  final protectedChanges = changedFiles.where(_isProtectedPath).toList();

  if (protectedChanges.isEmpty) {
    stdout.writeln(
        'Timeline runtime guardrail passed: no protected files changed.');
    return;
  }

  final approved = Platform.environment['TIMELINE_RUNTIME_APPROVED'] == '1';
  final reason = Platform.environment['TIMELINE_RUNTIME_CHANGE_REASON'];
  if (approved && reason != null && reason.trim().isNotEmpty) {
    stdout.writeln('Timeline runtime protected change approved: $reason');
    for (final path in protectedChanges) {
      stdout.writeln('- $path');
    }
    return;
  }

  stderr.writeln('Timeline runtime guardrail failed.');
  stderr.writeln('');
  stderr.writeln('The following protected runtime files changed:');
  for (final path in protectedChanges) {
    stderr.writeln('- $path');
  }
  stderr.writeln('');
  stderr.writeln('This is allowed only when the change is explicit.');
  stderr.writeln('Set both environment variables before rerunning:');
  stderr.writeln('');
  stderr.writeln('TIMELINE_RUNTIME_APPROVED=1');
  stderr.writeln('TIMELINE_RUNTIME_CHANGE_REASON="short reason"');
  stderr.writeln('');
  stderr
      .writeln('Do not use approval for incidental Scope/FX/Transition work.');
  exitCode = 2;
}

Future<List<String>> _changedFiles(List<String> args) async {
  final baseArg = args.where((arg) => arg.startsWith('--base=')).firstOrNull;
  if (baseArg != null) {
    final base = baseArg.substring('--base='.length);
    return _gitLines(<String>['diff', '--name-only', base, '--']);
  }
  if (args.contains('--staged')) {
    return _gitLines(<String>['diff', '--cached', '--name-only']);
  }
  final tracked = await _gitLines(<String>['diff', '--name-only']);
  final untracked = await _gitLines(
    <String>['ls-files', '--others', '--exclude-standard'],
  );
  return <String>{...tracked, ...untracked}.toList()..sort();
}

Future<List<String>> _gitLines(List<String> gitArgs) async {
  final result = await Process.run('git', gitArgs);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    exit(result.exitCode);
  }
  return LineSplitter.split(result.stdout.toString())
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

bool _isProtectedPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return protectedRuntimePaths.any((protectedPath) {
    return normalized == protectedPath ||
        normalized.endsWith('/$protectedPath');
  });
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}

class LineSplitter {
  static Iterable<String> split(String value) {
    return value.split(RegExp(r'\r?\n'));
  }
}
