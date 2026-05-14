import 'refusion_creative_launch_readiness.dart';
import 'refusion_creative_library_discovery.dart';
import 'refusion_mcp_mvp_toolkit.dart';

class RefusionMcpCreativeRuntimeAdapter {
  const RefusionMcpCreativeRuntimeAdapter({
    required RefusionCreativeLibraryDiscoveryToolset discoveryToolset,
    required RefusionCreativeLaunchReadinessToolset launchReadinessToolset,
  })  : _discoveryToolset = discoveryToolset,
        _launchReadinessToolset = launchReadinessToolset;

  final RefusionCreativeLibraryDiscoveryToolset _discoveryToolset;
  final RefusionCreativeLaunchReadinessToolset _launchReadinessToolset;

  RefusionMcpCreativeLibraryDiscoveryReader get discoveryReader =>
      ({required String toolName, Map<String, Object?> payload = const {}}) {
        return _discoveryToolset.invoke(toolName: toolName, payload: payload);
      };

  RefusionMcpLaunchReadinessReader get launchReadinessReader =>
      (Map<String, Object?> payload) {
        return _launchReadinessToolset.invoke(
          toolName: 'get_launch_readiness',
          payload: payload,
        );
      };
}
