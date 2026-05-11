import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_timeline_presentation_flags.dart';

void main() {
  test('defaults rollout to stable after PUTP closure', () {
    expect(
      UnifiedTimelinePresentationFlags.rolloutMode,
      UnifiedTimelinePresentationRolloutMode.stable,
    );
    expect(
      UnifiedTimelinePresentationFlags.unifiedTimelinePresentationLayer,
      isTrue,
    );
    expect(
        UnifiedTimelinePresentationFlags.unifiedTimelineInternalBuild, isFalse);
    expect(UnifiedTimelinePresentationFlags.unifiedTimelineBetaBuild, isFalse);
    expect(UnifiedTimelinePresentationFlags.unifiedTimelineStableBuild, isTrue);
  });
}
