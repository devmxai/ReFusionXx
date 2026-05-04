import '../../domain/models/composition_scene_clip_models.dart';
import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import 'universal_target_resolver.dart';

class UniversalMotionChannelCollectionSource {
  const UniversalMotionChannelCollectionSource({
    required this.id,
    required this.channels,
  });

  final String id;
  final Iterable<MotionPropertyChannelModel> channels;
}

class UniversalMotionChannelCollectionResult {
  UniversalMotionChannelCollectionResult({
    required List<MotionPropertyChannelModel> channels,
    List<String> diagnostics = const <String>[],
    List<String> blockers = const <String>[],
  })  : channels = List.unmodifiable(channels),
        diagnostics = List.unmodifiable(diagnostics),
        blockers = List.unmodifiable(blockers);

  final List<MotionPropertyChannelModel> channels;
  final List<String> diagnostics;
  final List<String> blockers;
}

class UniversalMotionChannelCollector {
  const UniversalMotionChannelCollector({
    this.targetResolver = const UniversalTargetResolver(),
  });

  final UniversalTargetResolver targetResolver;

  UniversalMotionChannelCollectionResult collect({
    required MotionProjectModel project,
    required List<CompositionSceneClipModel> sceneClips,
    required List<UniversalMotionChannelCollectionSource> sources,
  }) {
    final context = targetResolver.buildContext(
      project: project,
      sceneClips: sceneClips,
    );
    final byChannelId = <String, MotionPropertyChannelModel>{};
    final diagnostics = <String>[];
    final blockers = <String>[];
    for (final source in sources) {
      for (final channel in source.channels) {
        final resolution = targetResolver.resolveChannel(
          channel: channel,
          context: context,
        );
        diagnostics.addAll(
          resolution.diagnostics.map(
            (entry) => 'target_resolution:${source.id}:${channel.id}:$entry',
          ),
        );
        final resolvedChannel = resolution.channel;
        if (resolvedChannel == null) {
          blockers.add(
            'unresolved_target:${source.id}:${channel.id}:${resolution.blocker ?? 'unknown'}',
          );
          continue;
        }
        final existing = byChannelId[resolvedChannel.id];
        if (existing != null) {
          diagnostics.add(
            'duplicate_channel_ignored:${source.id}:${resolvedChannel.id}',
          );
          continue;
        }
        byChannelId[resolvedChannel.id] = resolvedChannel;
      }
    }
    return UniversalMotionChannelCollectionResult(
      channels: byChannelId.values.toList(growable: false),
      diagnostics: diagnostics,
      blockers: blockers,
    );
  }
}
