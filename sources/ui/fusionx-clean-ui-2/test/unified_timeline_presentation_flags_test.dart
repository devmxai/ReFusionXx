import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_timeline_presentation_flags.dart';

void main() {
  test('defaults rollout to off for safe production fallback', () {
    expect(
      UnifiedTimelinePresentationFlags.rolloutMode,
      UnifiedTimelinePresentationRolloutMode.off,
    );
    expect(
      UnifiedTimelinePresentationFlags.unifiedTimelinePresentationLayer,
      isFalse,
    );
    expect(
        UnifiedTimelinePresentationFlags.unifiedTimelineInternalBuild, isFalse);
    expect(UnifiedTimelinePresentationFlags.unifiedTimelineBetaBuild, isFalse);
    expect(
        UnifiedTimelinePresentationFlags.unifiedTimelineStableBuild, isFalse);
  });
}
