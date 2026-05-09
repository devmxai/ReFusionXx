import '../models/scene_director_brief_models.dart';
import 'scene_director_intelligence_planner.dart';

class SceneDirectorPlanner {
  const SceneDirectorPlanner({
    SceneDirectorIntelligencePlanner planner =
        const SceneDirectorIntelligencePlanner(),
  }) : _planner = planner;

  final SceneDirectorIntelligencePlanner _planner;

  SceneDirectorIntelligencePlanResult plan(SceneDirectorBrief brief) {
    return _planner.planFromBrief(brief);
  }
}
