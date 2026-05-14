import '../creative_library/services/professional_creative_library_discovery_service.dart';
import '../creative_library/models/professional_creative_library_discovery_models.dart';

class RefusionCreativeLibraryDiscoveryToolset {
  const RefusionCreativeLibraryDiscoveryToolset({
    required ProfessionalCreativeLibraryDiscoveryService discovery,
  }) : _discovery = discovery;

  final ProfessionalCreativeLibraryDiscoveryService _discovery;

  Map<String, Object?> invoke({
    required String toolName,
    Map<String, Object?> payload = const <String, Object?>{},
  }) {
    switch (toolName) {
      case 'list_components':
        return _discovery.listComponents().toJson();
      case 'list_effects':
        return _discovery.listEffects().toJson();
      case 'list_motion_recipes':
        return _discovery.listMotionRecipes().toJson();
      case 'list_templates':
        return _discovery.listTemplates().toJson();
      case 'list_icons':
        return _discovery.listIcons().toJson();
      case 'describe_component':
        return _describe(
          _discovery.describeComponent(payload['id'] as String? ?? ''),
          toolName,
        );
      case 'describe_effect':
        return _describe(
          _discovery.describeEffect(payload['id'] as String? ?? ''),
          toolName,
        );
      case 'describe_motion_recipe':
        return _describe(
          _discovery.describeMotionRecipe(payload['id'] as String? ?? ''),
          toolName,
        );
      case 'describe_template':
        return _describe(
          _discovery.describeTemplate(payload['id'] as String? ?? ''),
          toolName,
        );
      case 'describe_icon':
        return _describe(
          _discovery.describeIcon(payload['id'] as String? ?? ''),
          toolName,
        );
      default:
        return <String, Object?>{
          'error': 'unsupported_discovery_tool',
          'toolName': toolName,
        };
    }
  }

  Map<String, Object?> _describe(
    CreativeLibraryDiscoveryDescribeResponse? response,
    String toolName,
  ) {
    if (response == null) {
      return <String, Object?>{
        'error': 'not_found',
        'toolName': toolName,
      };
    }
    return response.toJson();
  }
}
