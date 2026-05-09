class SceneBrandMotionProfile {
  const SceneBrandMotionProfile({
    required this.id,
    required this.style,
    required this.shellEnterRecipe,
    required this.shellExitRecipe,
    required this.iconEnterRecipe,
    required this.labelEnterRecipe,
    required this.bodyEnterRecipe,
    this.allowElastic = false,
  });

  final String id;
  final String style;
  final String shellEnterRecipe;
  final String shellExitRecipe;
  final String iconEnterRecipe;
  final String labelEnterRecipe;
  final String bodyEnterRecipe;
  final bool allowElastic;
}
