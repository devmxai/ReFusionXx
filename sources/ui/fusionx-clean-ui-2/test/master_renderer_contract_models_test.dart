import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_renderer_adapter_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_renderer_contract_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  test('builds stable live scrub request ids and surface ids', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(5000),
      initialTime: ms(1200),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.liveScrub,
      sourceScope: MasterTimeScope.rootComposition,
    );

    final programRequestId =
        MasterRendererContracts.liveScrubProgramRequestId(time);
    final descriptorRequestId =
        MasterRendererContracts.liveScrubDescriptorRequestId(time);

    expect(programRequestId.startsWith('mlsp:'), isTrue);
    expect(descriptorRequestId.startsWith('liveScrub:'), isTrue);
    expect(
      MasterRendererContracts.liveScrubRuntimeBridgeSurfaceId,
      'stage5-runtime-bridge',
    );
    expect(
      MasterRendererContracts.liveScrubDescriptorSurfaceId,
      'stage5-scrub-surface',
    );
  });

  test('builds mode-aware descriptor request and surface contracts', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(5000),
      initialTime: ms(1200),
    );
    final previewTime = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.preview,
      sourceScope: MasterTimeScope.rootComposition,
    );
    final playbackTime = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.playback,
      sourceScope: MasterTimeScope.rootComposition,
    );

    expect(
      MasterRendererContracts.descriptorRequestIdForMode(
        mode: MasterRendererAdapterMode.preview,
        time: previewTime,
      ).startsWith('preview:'),
      isTrue,
    );
    expect(
      MasterRendererContracts.descriptorRequestIdForMode(
        mode: MasterRendererAdapterMode.playback,
        time: playbackTime,
      ).startsWith('playback:'),
      isTrue,
    );
    expect(
      MasterRendererContracts.runtimeBridgeSurfaceIdForMode(
        MasterRendererAdapterMode.preview,
      ),
      'stage5-preview-surface',
    );
    expect(
      MasterRendererContracts.runtimeBridgeSurfaceIdForMode(
        MasterRendererAdapterMode.playback,
      ),
      'stage5-playback-surface',
    );
  });
}
