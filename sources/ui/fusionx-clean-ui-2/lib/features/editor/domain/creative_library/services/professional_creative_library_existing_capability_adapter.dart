import '../../mcp/refusion_mcp_tool_registry.dart';
import '../../services/master_value_truth_registry.dart';
import '../../services/professional_speed_graph_preset_catalog.dart';
import '../../services/scene_icon_registry.dart';
import '../../services/scene_micro_scene_registry.dart';
import '../../services/scene_motion_recipe_library.dart';
import '../../services/scene_semantic_component_registry.dart';
import '../models/professional_creative_library_registry_models.dart';
import 'professional_creative_library_registry.dart';

class ProfessionalCreativeLibraryExistingCapabilityAdapter {
  ProfessionalCreativeLibraryExistingCapabilityAdapter({
    SceneMotionRecipeLibrary? motionRecipes,
    SceneSemanticComponentRegistry? components,
    SceneIconRegistry? icons,
    SceneMicroSceneRegistry? microScenes,
    this.mcpTools,
    this.masterValues,
    ProfessionalSpeedGraphPresetCatalog? speedGraphCatalog,
  })  : motionRecipes = motionRecipes ?? const SceneMotionRecipeLibrary(),
        components = components ?? SceneSemanticComponentRegistry(),
        icons = icons ?? const SceneIconRegistry(),
        microScenes = microScenes ?? const SceneMicroSceneRegistry(),
        speedGraphCatalog =
            speedGraphCatalog ?? const ProfessionalSpeedGraphPresetCatalog();

  final SceneMotionRecipeLibrary motionRecipes;
  final SceneSemanticComponentRegistry components;
  final SceneIconRegistry icons;
  final SceneMicroSceneRegistry microScenes;
  final RefusionMcpToolRegistry? mcpTools;
  final MasterValueTruthRegistry? masterValues;
  final ProfessionalSpeedGraphPresetCatalog speedGraphCatalog;

  ProfessionalCreativeLibraryRegistry buildRegistry() {
    final wrappedItems = <CreativeLibraryItemDefinition>[
      ..._wrapMotionRecipes(),
      ..._wrapComponents(),
      ..._wrapIconTokens(),
      ..._wrapTemplateMicroScenes(),
      ..._wrapCoreEffects(),
    ];

    return ProfessionalCreativeLibraryRegistry(
      items: wrappedItems,
      adapters: const <EntrySurfaceAdapterDefinition>[
        EntrySurfaceAdapterDefinition(
          id: 'adapter.manual_ui',
          surface: SupportedEntrySurface.manualUi,
          commandFamilies: <CommandFamilyDefinition>{
            CommandFamilyDefinition.insertComponent,
            CommandFamilyDefinition.applyEffect,
            CommandFamilyDefinition.applyMotionRecipe,
            CommandFamilyDefinition.insertText,
            CommandFamilyDefinition.updateText,
            CommandFamilyDefinition.insertShape,
            CommandFamilyDefinition.insertMedia,
          },
          emitsEnvelope: true,
          directMutationCount: 0,
        ),
        EntrySurfaceAdapterDefinition(
          id: 'adapter.mcp',
          surface: SupportedEntrySurface.mcp,
          commandFamilies: <CommandFamilyDefinition>{
            CommandFamilyDefinition.insertComponent,
            CommandFamilyDefinition.updateComponent,
            CommandFamilyDefinition.applyEffect,
            CommandFamilyDefinition.applyMotionRecipe,
            CommandFamilyDefinition.editKeyframe,
            CommandFamilyDefinition.updateMediaBinding,
            CommandFamilyDefinition.updateExposedControl,
          },
          emitsEnvelope: true,
          directMutationCount: 0,
        ),
        EntrySurfaceAdapterDefinition(
          id: 'adapter.paste_script',
          surface: SupportedEntrySurface.pasteScript,
          commandFamilies: <CommandFamilyDefinition>{
            CommandFamilyDefinition.insertComponent,
            CommandFamilyDefinition.updateComponent,
            CommandFamilyDefinition.applyEffect,
            CommandFamilyDefinition.applyMotionRecipe,
            CommandFamilyDefinition.applyKeyframes,
            CommandFamilyDefinition.editKeyframe,
            CommandFamilyDefinition.compileTemplate,
          },
          emitsEnvelope: true,
          directMutationCount: 0,
        ),
        EntrySurfaceAdapterDefinition(
          id: 'adapter.template',
          surface: SupportedEntrySurface.template,
          commandFamilies: <CommandFamilyDefinition>{
            CommandFamilyDefinition.insertTemplate,
            CommandFamilyDefinition.compileTemplate,
            CommandFamilyDefinition.updateExposedControl,
          },
          emitsEnvelope: true,
          directMutationCount: 0,
        ),
        EntrySurfaceAdapterDefinition(
          id: 'adapter.tap_list',
          surface: SupportedEntrySurface.tapList,
          commandFamilies: <CommandFamilyDefinition>{
            CommandFamilyDefinition.insertComponent,
            CommandFamilyDefinition.insertTemplate,
            CommandFamilyDefinition.applyMotionRecipe,
            CommandFamilyDefinition.applyEffect,
          },
          emitsEnvelope: true,
          directMutationCount: 0,
        ),
        EntrySurfaceAdapterDefinition(
          id: 'adapter.future_tool',
          surface: SupportedEntrySurface.futureTool,
          commandFamilies: <CommandFamilyDefinition>{
            CommandFamilyDefinition.insertComponent,
            CommandFamilyDefinition.updateComponent,
            CommandFamilyDefinition.applyEffect,
            CommandFamilyDefinition.applyMotionRecipe,
            CommandFamilyDefinition.applyKeyframes,
            CommandFamilyDefinition.editKeyframe,
            CommandFamilyDefinition.compileTemplate,
            CommandFamilyDefinition.updateExposedControl,
          },
          emitsEnvelope: true,
          directMutationCount: 0,
        ),
      ],
    );
  }

  List<ExistingCapabilityAuditRecord> auditRecords() {
    final records = <ExistingCapabilityAuditRecord>[];

    for (final recipe in motionRecipes.all) {
      records.add(
        ExistingCapabilityAuditRecord(
          capabilityId: '\$motion.${recipe.id}',
          capabilityFamily: 'motionRecipe',
          revisionScope: 'PNCLE-02',
          localCodeReferences: const <String>[
            'lib/features/editor/domain/services/scene_motion_recipe_library.dart',
            'lib/features/editor/domain/services/scene_motion_recipe_compiler.dart',
          ],
          reviewDecision: ExistingCapabilityReviewDecision.wrap,
          reason:
              'Working recipe library is retained and exposed through registry contract.',
        ),
      );
    }

    for (final componentId in components.supportedComponentIds) {
      records.add(
        ExistingCapabilityAuditRecord(
          capabilityId: r'$component.' + _camelToToken(componentId),
          capabilityFamily: 'component',
          revisionScope: 'PNCLE-02',
          localCodeReferences: const <String>[
            'lib/features/editor/domain/services/scene_semantic_component_registry.dart',
          ],
          reviewDecision: ExistingCapabilityReviewDecision.wrap,
          reason:
              'Semantic component is already validated and now exposed from registry as canonical source.',
        ),
      );
    }

    records.addAll(
      const <ExistingCapabilityAuditRecord>[
        ExistingCapabilityAuditRecord(
          capabilityId: r'$effect.motionBlur',
          capabilityFamily: 'effect',
          revisionScope: 'PNCLE-02',
          localCodeReferences: <String>[
            'lib/features/editor/domain/services/motion_blur_velocity_compiler.dart',
            'lib/features/editor/domain/services/master_render_graph_adapter.dart',
            'lib/features/editor/domain/services/trueframe_core_runtime_evaluator.dart',
          ],
          reviewDecision: ExistingCapabilityReviewDecision.upgrade,
          reason:
              'Native implementation exists; needs broader preset language and stronger parity benchmarks.',
        ),
        ExistingCapabilityAuditRecord(
          capabilityId: r'$effect.gaussianBlur',
          capabilityFamily: 'effect',
          revisionScope: 'PNCLE-02',
          localCodeReferences: <String>[
            'lib/features/editor/domain/services/master_value_truth_registry.dart',
            'lib/features/editor/domain/services/trueframe_core_runtime_evaluator.dart',
          ],
          reviewDecision: ExistingCapabilityReviewDecision.wrap,
          reason:
              'Blur capability is live in runtime/value-truth and should be exposed through the same registry contract.',
        ),
        ExistingCapabilityAuditRecord(
          capabilityId: r'$motion.transformStack',
          capabilityFamily: 'motion',
          revisionScope: 'PNCLE-02',
          localCodeReferences: <String>[
            'lib/features/editor/domain/services/master_value_truth_registry.dart',
            'lib/features/editor/domain/services/refusion_mcp_motion_tools.dart',
            'lib/features/editor/domain/services/refusion_scene_program_lowerer.dart',
          ],
          reviewDecision: ExistingCapabilityReviewDecision.wrap,
          reason:
              'Position/scale/rotation/opacity stack is implemented and should be one canonical capability entry.',
        ),
        ExistingCapabilityAuditRecord(
          capabilityId: r'$motion.keyframes',
          capabilityFamily: 'motion',
          revisionScope: 'PNCLE-02',
          localCodeReferences: <String>[
            'lib/features/editor/domain/services/unified_keyframe_operations.dart',
            'lib/features/editor/domain/mcp/refusion_mcp_motion_tools.dart',
          ],
          reviewDecision: ExistingCapabilityReviewDecision.wrap,
          reason:
              'Unified keyframe engine exists and must be explicitly discoverable as first-class capability.',
        ),
        ExistingCapabilityAuditRecord(
          capabilityId: r'$text.insertUpdate',
          capabilityFamily: 'text',
          revisionScope: 'PNCLE-02',
          localCodeReferences: <String>[
            'lib/features/editor/domain/mcp/refusion_mcp_tool_registry.dart',
            'lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart',
          ],
          reviewDecision: ExistingCapabilityReviewDecision.upgrade,
          reason:
              'Text insert/update paths exist but require tighter canonical command unification.',
        ),
        ExistingCapabilityAuditRecord(
          capabilityId: r'$shape.background',
          capabilityFamily: 'shape',
          revisionScope: 'PNCLE-02',
          localCodeReferences: <String>[
            'lib/features/editor/domain/services/refusion_scene_program_lowerer.dart',
            'lib/features/editor/domain/services/master_value_truth_registry.dart',
          ],
          reviewDecision: ExistingCapabilityReviewDecision.wrap,
          reason:
              'Shape/background channels are implemented and now registered with conformance metadata.',
        ),
        ExistingCapabilityAuditRecord(
          capabilityId: r'$media.videoImage',
          capabilityFamily: 'media',
          revisionScope: 'PNCLE-02',
          localCodeReferences: <String>[
            'lib/features/editor/domain/models/export_composition_models.dart',
            'lib/features/editor/domain/mcp/refusion_mcp_tool_registry.dart',
          ],
          reviewDecision: ExistingCapabilityReviewDecision.wrap,
          reason:
              'Media image/video capabilities are active and need single-source registry discovery.',
        ),
      ],
    );

    return List<ExistingCapabilityAuditRecord>.unmodifiable(records);
  }

  List<MotionRecipeDefinition> _wrapMotionRecipes() {
    return motionRecipes.all
        .map(
          (recipe) => MotionRecipeDefinition(
            id: '\$motion.${recipe.id}',
            version: 'v1',
            title: recipe.id,
            description: recipe.tasteNotes,
            category: 'motion.${recipe.category.name}',
            tags: <String>[recipe.category.name, ...recipe.allowedTargets],
            sourceInspiration: 'Refusion native motion recipe library',
            licenseStatus: 'internal',
            supportedNodeFamilies:
                recipe.allowedTargets.toList(growable: false),
            parameterSchema: const <String, Object?>{
              'durationMs': <String, Object?>{'type': 'number', 'minimum': 16},
              'staggerMs': <String, Object?>{'type': 'number', 'minimum': 0},
            },
            defaultParams: <String, Object?>{
              'durationToken': recipe.defaultDurationToken,
              'easingToken': recipe.easingToken,
              'staggerMs': recipe.staggerMs,
              'motionBlur': recipe.motionBlur,
            },
            requiredAssets: const <String>[],
            supportedAspectRatios: const <String>['16:9', '9:16', '1:1'],
            defaultDurationMs: _durationTokenMs(recipe.defaultDurationToken),
            timelineBehavior: 'keyframeDriven',
            spatialBehavior: 'transform2d',
            compileContract:
                'scene_motion_recipe_compiler -> refusion_scene_program_lowerer',
            loweringContract: 'SceneProgram channels -> MotionPropertyCatalog',
            manualUiControls: const <ManualUiControlDefinition>[
              ManualUiControlDefinition(
                id: 'durationMs',
                label: 'Duration',
                controlType: 'slider',
              ),
            ],
            mcpExamples: const <McpToolExposureDefinition>[
              McpToolExposureDefinition(
                toolName: 'refusion.apply_motion_patch',
                mode: 'mutating',
                notes: 'Recipe compiles into canonical keyframe commands.',
              ),
            ],
            pasteScriptExamples: <String>['apply_motion_recipe(${recipe.id})'],
            templateExamples: const <String>['scene_micro_scene_registry'],
            previewPoster: 'assets/previews/motion/${recipe.id}.png',
            previewMotion: 'assets/previews/motion/${recipe.id}.mp4',
            qaRules: const <QaRuleDefinition>[
              QaRuleDefinition(
                id: 'qa.motion.no_metadata_only_success',
                description: 'Motion must produce channel/keyframe mutations.',
                severity: 'error',
              ),
            ],
            rendererConformance: _defaultRendererConformance,
            exportConformance: _defaultExportConformance,
            capabilityBenchmark: _benchmark(
              capabilityId: '\$motion.${recipe.id}',
              family: 'motionRecipe',
              codeReferences: const <String>[
                'lib/features/editor/domain/services/scene_motion_recipe_library.dart',
                'lib/features/editor/domain/services/scene_motion_recipe_compiler.dart',
              ],
              benchmarkScenes: const <String>[
                'fast_linear_motion',
                'scale_rotation_combo',
              ],
            ),
            benchmarkDecision: CapabilityBenchmarkDecision.wrap,
            legacyPathCleanup: _defaultCleanupDecisionMap(),
            supportedEntrySurfaces: _defaultEntrySurfaces,
            failureMode: 'blocked',
            speedyGraphPreset:
                speedGraphCatalog.canonicalId(recipe.speedyGraphPreset),
          ),
        )
        .toList(growable: false);
  }

  List<ComponentDefinition> _wrapComponents() {
    return components.supportedComponentIds.map(
      (componentId) {
        final definition = components.findByType(componentId);
        return ComponentDefinition(
          id: '\$component.${_camelToToken(componentId)}',
          version: 'v1',
          title: componentId,
          description:
              'Semantic component from existing SceneSemanticComponentRegistry.',
          category: 'component.semantic',
          tags: <String>[
            componentId,
            if (definition != null) ...definition.aliases,
          ],
          sourceInspiration: 'Refusion semantic component registry',
          licenseStatus: 'internal',
          supportedNodeFamilies: const <String>[
            'component',
            'slot',
            'text',
            'icon',
            'shape',
            'image',
            'video',
          ],
          parameterSchema: const <String, Object?>{
            'variant': <String, Object?>{'type': 'string'},
            'slots': <String, Object?>{'type': 'object'},
          },
          defaultParams: const <String, Object?>{'variant': 'default'},
          requiredAssets: const <String>[],
          supportedAspectRatios: const <String>['16:9', '9:16', '1:1'],
          defaultDurationMs: 1200,
          timelineBehavior: 'componentBeatScoped',
          spatialBehavior: 'componentDerived',
          compileContract:
              'scene_semantic_component_registry -> runtime template',
          loweringContract: 'runtime nodes -> SceneProgram elements',
          manualUiControls: const <ManualUiControlDefinition>[
            ManualUiControlDefinition(
              id: 'variant',
              label: 'Variant',
              controlType: 'select',
            ),
          ],
          mcpExamples: const <McpToolExposureDefinition>[
            McpToolExposureDefinition(
              toolName: 'refusion.insert_layer',
              mode: 'mutating',
              notes:
                  'Component insertion must compile to canonical insert command.',
            ),
          ],
          pasteScriptExamples: const <String>[
            'insert_component(PromptInputBar)'
          ],
          templateExamples: const <String>['template.productPromo'],
          previewPoster: 'assets/previews/components/$componentId.png',
          previewMotion: 'assets/previews/components/$componentId.mp4',
          qaRules: const <QaRuleDefinition>[
            QaRuleDefinition(
              id: 'qa.component.registry_contract',
              description: 'Component type and slot contract must validate.',
              severity: 'error',
            ),
          ],
          rendererConformance: _defaultRendererConformance,
          exportConformance: _defaultExportConformance,
          capabilityBenchmark: _benchmark(
            capabilityId: '\$component.${_camelToToken(componentId)}',
            family: 'component',
            codeReferences: const <String>[
              'lib/features/editor/domain/services/scene_semantic_component_registry.dart',
            ],
            benchmarkScenes: const <String>[
              'component_entrance',
              'component_text_layout',
            ],
          ),
          benchmarkDecision: CapabilityBenchmarkDecision.wrap,
          legacyPathCleanup: _defaultCleanupDecisionMap(),
          supportedEntrySurfaces: _defaultEntrySurfaces,
          failureMode: 'blocked',
          semanticType: componentId,
        );
      },
    ).toList(growable: false);
  }

  List<IconDefinition> _wrapIconTokens() {
    final semanticIcons = icons.semanticIcons.map(
      (icon) => IconDefinition(
        id: icon.id,
        version: 'v1',
        title: icon.iconName,
        description: 'Semantic icon token from SceneIconRegistry.',
        category: 'icon.${icon.category}',
        tags: icon.tags,
        sourceInspiration: 'Refusion icon registry',
        licenseStatus: 'internal',
        supportedNodeFamilies: const <String>['icon'],
        parameterSchema: const <String, Object?>{},
        defaultParams: const <String, Object?>{},
        requiredAssets: const <String>[],
        supportedAspectRatios: const <String>['16:9', '9:16', '1:1'],
        defaultDurationMs: 1000,
        timelineBehavior: 'staticOrKeyframed',
        spatialBehavior: 'transform2d',
        compileContract: 'icon token resolve -> element.iconName',
        loweringContract: 'icon element -> preview/export icon painter',
        manualUiControls: const <ManualUiControlDefinition>[],
        mcpExamples: const <McpToolExposureDefinition>[
          McpToolExposureDefinition(
            toolName: 'refusion.insert_layer',
            mode: 'mutating',
            notes: 'Icon token insertion.',
          ),
        ],
        pasteScriptExamples: const <String>[r'insert_icon($icon.send)'],
        templateExamples: const <String>['template.prompt'],
        previewPoster: 'assets/previews/icons/${icon.iconName}.png',
        previewMotion: 'assets/previews/icons/${icon.iconName}.mp4',
        qaRules: const <QaRuleDefinition>[
          QaRuleDefinition(
            id: 'qa.icon.registry_proof',
            description: 'Icon token must resolve in registry.',
            severity: 'error',
          ),
        ],
        rendererConformance: _defaultRendererConformance,
        exportConformance: _defaultExportConformance,
        capabilityBenchmark: _benchmark(
          capabilityId: icon.id,
          family: 'icon',
          codeReferences: const <String>[
            'lib/features/editor/domain/services/scene_icon_registry.dart',
          ],
          benchmarkScenes: const <String>['icon_reveal'],
        ),
        benchmarkDecision: CapabilityBenchmarkDecision.wrap,
        legacyPathCleanup: _defaultCleanupDecisionMap(),
        supportedEntrySurfaces: _defaultEntrySurfaces,
        failureMode: 'blocked',
        iconName: icon.iconName,
      ),
    );

    final brands = icons.brands.map(
      (brand) => IconDefinition(
        id: brand.id,
        version: 'v1',
        title: brand.displayName,
        description:
            'Brand token with legal fallback support from SceneIconRegistry.',
        category: 'brand.${brand.category}',
        tags: <String>['brand', brand.category],
        sourceInspiration: 'Refusion brand token registry',
        licenseStatus: brand.licenseStatus,
        supportedNodeFamilies: const <String>['icon', 'brand'],
        parameterSchema: const <String, Object?>{
          'fallbackIconToken': <String, Object?>{'type': 'string'},
        },
        defaultParams: <String, Object?>{
          'fallbackIconToken': brand.fallbackIconToken,
        },
        requiredAssets: const <String>[],
        supportedAspectRatios: const <String>['16:9', '9:16', '1:1'],
        defaultDurationMs: 1000,
        timelineBehavior: 'staticOrKeyframed',
        spatialBehavior: 'transform2d',
        compileContract: 'brand token resolve -> brand asset policy',
        loweringContract: 'brand token -> icon/asset fallback graph',
        manualUiControls: const <ManualUiControlDefinition>[],
        mcpExamples: const <McpToolExposureDefinition>[
          McpToolExposureDefinition(
            toolName: 'refusion.insert_layer',
            mode: 'mutating',
            notes: 'Brand token insertion with fallback policy.',
          ),
        ],
        pasteScriptExamples: const <String>[r'insert_brand($brand.chatgpt)'],
        templateExamples: const <String>['template.brandLogo'],
        previewPoster: 'assets/previews/brands/${brand.displayName}.png',
        previewMotion: 'assets/previews/brands/${brand.displayName}.mp4',
        qaRules: const <QaRuleDefinition>[
          QaRuleDefinition(
            id: 'qa.brand.legal_fallback',
            description:
                'Unknown or restricted brands must fallback to semantic icon path.',
            severity: 'error',
          ),
        ],
        rendererConformance: _defaultRendererConformance,
        exportConformance: _defaultExportConformance,
        capabilityBenchmark: _benchmark(
          capabilityId: brand.id,
          family: 'brand',
          codeReferences: const <String>[
            'lib/features/editor/domain/services/scene_icon_registry.dart',
            'lib/features/editor/domain/services/scene_brand_asset_policy.dart',
          ],
          benchmarkScenes: const <String>['brand_logo_intro'],
        ),
        benchmarkDecision: CapabilityBenchmarkDecision.wrap,
        legacyPathCleanup: _defaultCleanupDecisionMap(),
        supportedEntrySurfaces: _defaultEntrySurfaces,
        failureMode: 'blocked',
        iconName: brand.fallbackIconToken,
      ),
    );

    return <IconDefinition>[...semanticIcons, ...brands];
  }

  List<TemplateDefinition> _wrapTemplateMicroScenes() {
    return microScenes.ids.map(
      (id) {
        final spec = microScenes.find(id)!;
        return TemplateDefinition(
          id: '\$template.$id',
          version: 'v1',
          title: spec.kind,
          description: 'Existing semantic micro-scene template.',
          category: 'template.microScene',
          tags: <String>[spec.kind, spec.aspectBias],
          sourceInspiration: 'Refusion micro-scene registry',
          licenseStatus: 'internal',
          supportedNodeFamilies: const <String>[
            'shape',
            'text',
            'component',
            'media',
          ],
          parameterSchema: const <String, Object?>{
            'width': <String, Object?>{'type': 'number', 'minimum': 1},
            'height': <String, Object?>{'type': 'number', 'minimum': 1},
            'opacity': <String, Object?>{
              'type': 'number',
              'minimum': 0,
              'maximum': 1
            },
          },
          defaultParams: <String, Object?>{
            'width': spec.width,
            'height': spec.height,
            'opacity': spec.opacity,
            'motionRecipe': spec.motionRecipe,
          },
          requiredAssets: const <String>[],
          supportedAspectRatios: const <String>['16:9', '9:16', '1:1'],
          defaultDurationMs: 1200,
          timelineBehavior: 'templateCompiled',
          spatialBehavior: 'absoluteCanvas',
          compileContract: 'template -> SceneProgram + SceneCommand list',
          loweringContract: 'template graph -> source-scene nodes',
          manualUiControls: const <ManualUiControlDefinition>[
            ManualUiControlDefinition(
              id: 'opacity',
              label: 'Opacity',
              controlType: 'slider',
            ),
          ],
          mcpExamples: const <McpToolExposureDefinition>[
            McpToolExposureDefinition(
              toolName: 'refusion.apply_scene_program',
              mode: 'mutating',
              notes: 'Template compiled before apply.',
            ),
          ],
          pasteScriptExamples: const <String>['compile_template(microScene)'],
          templateExamples: const <String>['scene_micro_scene_registry'],
          previewPoster: 'assets/previews/templates/$id.png',
          previewMotion: 'assets/previews/templates/$id.mp4',
          qaRules: const <QaRuleDefinition>[
            QaRuleDefinition(
              id: 'qa.template.compile_contract',
              description: 'Template must compile into editable scene graph.',
              severity: 'error',
            ),
          ],
          rendererConformance: _defaultRendererConformance,
          exportConformance: _defaultExportConformance,
          capabilityBenchmark: _benchmark(
            capabilityId: '\$template.$id',
            family: 'template',
            codeReferences: const <String>[
              'lib/features/editor/domain/services/scene_micro_scene_registry.dart',
            ],
            benchmarkScenes: const <String>['template_apply_default'],
          ),
          benchmarkDecision: CapabilityBenchmarkDecision.wrap,
          legacyPathCleanup: _defaultCleanupDecisionMap(),
          supportedEntrySurfaces: _defaultEntrySurfaces,
          failureMode: 'blocked',
        );
      },
    ).toList(growable: false);
  }

  List<CreativeLibraryItemDefinition> _wrapCoreEffects() {
    final toolRegistry = mcpTools ?? RefusionMcpToolRegistry();
    final valueRegistry = masterValues ?? MasterValueTruthRegistry();

    final hasTransformStack = <String>[
      'position',
      'scale',
      'rotation',
      'opacity',
    ].every((id) => valueRegistry.definitionById(id) != null);

    final effectItems = <CreativeLibraryItemDefinition>[
      _effectItem(
        id: r'$effect.motionBlur',
        title: 'Motion Blur',
        description:
            'Velocity-aware shutter motion blur stack with live scrub/readiness integration.',
        tags: const <String>['blur', 'motion', 'shutter', 'temporal'],
        benchmarkDecision: CapabilityBenchmarkDecision.upgrade,
        codeReferences: const <String>[
          'lib/features/editor/domain/services/motion_blur_velocity_compiler.dart',
          'lib/features/editor/domain/services/master_render_graph_adapter.dart',
          'lib/features/editor/domain/services/trueframe_core_runtime_evaluator.dart',
        ],
      ),
      _effectItem(
        id: r'$effect.gaussianBlur',
        title: 'Gaussian Blur',
        description:
            'Layer blur amount mapped through value truth and runtime evaluator.',
        tags: const <String>['blur', 'gaussian', 'soften'],
        benchmarkDecision: CapabilityBenchmarkDecision.wrap,
        codeReferences: const <String>[
          'lib/features/editor/domain/services/master_value_truth_registry.dart',
          'lib/features/editor/domain/services/trueframe_core_runtime_evaluator.dart',
        ],
      ),
      _expressionItem(
        id: r'$motion.transformStack',
        title: 'Transform Stack (Position/Scale/Rotation/Opacity)',
        description: hasTransformStack
            ? 'Transform stack is wired in master value truth and scene lowerers.'
            : 'Transform stack wiring is incomplete and should be upgraded.',
        tags: const <String>['position', 'scale', 'rotation', 'opacity'],
        benchmarkDecision: hasTransformStack
            ? CapabilityBenchmarkDecision.wrap
            : CapabilityBenchmarkDecision.upgrade,
        codeReferences: const <String>[
          'lib/features/editor/domain/services/master_value_truth_registry.dart',
          'lib/features/editor/domain/services/refusion_scene_program_lowerer.dart',
          'lib/features/editor/domain/mcp/refusion_mcp_motion_tools.dart',
        ],
      ),
      _expressionItem(
        id: r'$motion.keyframes',
        title: 'Unified Keyframes',
        description:
            'Add/move/delete/ease keyframes through unified operations and MCP motion tools.',
        tags: const <String>['keyframe', 'graph', 'timeline'],
        benchmarkDecision: CapabilityBenchmarkDecision.wrap,
        codeReferences: const <String>[
          'lib/features/editor/domain/services/unified_keyframe_operations.dart',
          'lib/features/editor/domain/mcp/refusion_mcp_motion_tools.dart',
        ],
      ),
      _expressionItem(
        id: r'$text.insertUpdate',
        title: 'Text Insert/Update',
        description:
            'Text authoring via insert/update command surfaces with schema-driven validation.',
        tags: const <String>['text', 'insert', 'update'],
        benchmarkDecision: CapabilityBenchmarkDecision.upgrade,
        codeReferences: const <String>[
          'lib/features/editor/domain/mcp/refusion_mcp_tool_registry.dart',
          'lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart',
        ],
      ),
      _expressionItem(
        id: r'$shape.background',
        title: 'Shape and Background',
        description:
            'Shape/background channels and styling are lowered through scene programs and value truth.',
        tags: const <String>['shape', 'background', 'color'],
        benchmarkDecision: CapabilityBenchmarkDecision.wrap,
        codeReferences: const <String>[
          'lib/features/editor/domain/services/refusion_scene_program_lowerer.dart',
          'lib/features/editor/domain/services/master_value_truth_registry.dart',
        ],
      ),
      _expressionItem(
        id: r'$media.videoImage',
        title: 'Media Video/Image',
        description:
            'Image/video layer paths exist in MCP tool registry and export composition pipeline.',
        tags: const <String>['media', 'video', 'image'],
        benchmarkDecision: CapabilityBenchmarkDecision.wrap,
        codeReferences: const <String>[
          'lib/features/editor/domain/mcp/refusion_mcp_tool_registry.dart',
          'lib/features/editor/domain/models/export_composition_models.dart',
        ],
      ),
    ];

    final mcpToolNameSet = toolRegistry.list().map((tool) => tool.name).toSet();
    if (!mcpToolNameSet.contains('refusion.keyframe_edit')) {
      return effectItems
          .map(
            (item) =>
                item is ExpressionDefinition && item.id == r'$motion.keyframes'
                    ? _expressionItem(
                        id: item.id,
                        title: item.title,
                        description:
                            '${item.description} MCP keyframe edit tool is currently not exposed.',
                        tags: item.tags,
                        benchmarkDecision: CapabilityBenchmarkDecision.upgrade,
                        codeReferences: item.capabilityBenchmark.codeReferences,
                      )
                    : item,
          )
          .toList(growable: false);
    }

    return effectItems;
  }

  EffectDefinition _effectItem({
    required String id,
    required String title,
    required String description,
    required List<String> tags,
    required CapabilityBenchmarkDecision benchmarkDecision,
    required List<String> codeReferences,
  }) {
    return EffectDefinition(
      id: id,
      version: 'v1',
      title: title,
      description: description,
      category: 'effect',
      tags: tags,
      sourceInspiration: 'Refusion native effect runtime',
      licenseStatus: 'internal',
      supportedNodeFamilies: const <String>['layer', 'element', 'media'],
      parameterSchema: const <String, Object?>{
        'amount': <String, Object?>{'type': 'number', 'minimum': 0},
      },
      defaultParams: const <String, Object?>{'amount': 0.0},
      requiredAssets: const <String>[],
      supportedAspectRatios: const <String>['16:9', '9:16', '1:1'],
      defaultDurationMs: 1000,
      timelineBehavior: 'keyframeDrivenOrStatic',
      spatialBehavior: 'effectStackPostTransform',
      compileContract: 'applyEffect -> effect instance on target',
      loweringContract: 'effect instance -> render graph/evaluator',
      manualUiControls: const <ManualUiControlDefinition>[
        ManualUiControlDefinition(
          id: 'amount',
          label: 'Amount',
          controlType: 'slider',
        ),
      ],
      mcpExamples: const <McpToolExposureDefinition>[
        McpToolExposureDefinition(
          toolName: 'refusion.set_layer_style',
          mode: 'mutating',
          notes: 'Effect params compile through canonical update path.',
        ),
      ],
      pasteScriptExamples: const <String>['apply_effect(target, effect)'],
      templateExamples: const <String>['template.effectIntro'],
      previewPoster: 'assets/previews/effects/$id.png',
      previewMotion: 'assets/previews/effects/$id.mp4',
      qaRules: const <QaRuleDefinition>[
        QaRuleDefinition(
          id: 'qa.effect.non_metadata_only',
          description:
              'Effect apply is invalid if it only writes metadata and produces no runtime graph state.',
          severity: 'error',
        ),
      ],
      rendererConformance: _defaultRendererConformance,
      exportConformance: _defaultExportConformance,
      capabilityBenchmark: _benchmark(
        capabilityId: id,
        family: 'effect',
        codeReferences: codeReferences,
        benchmarkScenes: const <String>[
          'effect_layer_motion',
          'effect_text_overlay'
        ],
      ),
      benchmarkDecision: benchmarkDecision,
      legacyPathCleanup: _defaultCleanupDecisionMap(),
      supportedEntrySurfaces: _defaultEntrySurfaces,
      failureMode: 'blocked',
      effectStackStage: 'postTransform',
    );
  }

  ExpressionDefinition _expressionItem({
    required String id,
    required String title,
    required String description,
    required List<String> tags,
    required CapabilityBenchmarkDecision benchmarkDecision,
    required List<String> codeReferences,
  }) {
    return ExpressionDefinition(
      id: id,
      version: 'v1',
      title: title,
      description: description,
      category: 'capability',
      tags: tags,
      sourceInspiration: 'Refusion existing capability audit',
      licenseStatus: 'internal',
      supportedNodeFamilies: const <String>['layer', 'element', 'channel'],
      parameterSchema: const <String, Object?>{},
      defaultParams: const <String, Object?>{},
      requiredAssets: const <String>[],
      supportedAspectRatios: const <String>['16:9', '9:16', '1:1'],
      defaultDurationMs: 1000,
      timelineBehavior: 'channelDriven',
      spatialBehavior: 'dependsOnTarget',
      compileContract: 'canonical command family compilation',
      loweringContract: 'lowered through motion/effect/channel runtime',
      manualUiControls: const <ManualUiControlDefinition>[],
      mcpExamples: const <McpToolExposureDefinition>[
        McpToolExposureDefinition(
          toolName: 'refusion.explain_capabilities',
          mode: 'read-only',
          notes: 'Discovery and explain tool support.',
        ),
      ],
      pasteScriptExamples: const <String>['describe_capability(id)'],
      templateExamples: const <String>[],
      previewPoster: 'assets/previews/capabilities/$id.png',
      previewMotion: 'assets/previews/capabilities/$id.mp4',
      qaRules: const <QaRuleDefinition>[
        QaRuleDefinition(
          id: 'qa.capability.single_truth',
          description: 'Capability must avoid parallel truth paths.',
          severity: 'error',
        ),
      ],
      rendererConformance: _defaultRendererConformance,
      exportConformance: _defaultExportConformance,
      capabilityBenchmark: _benchmark(
        capabilityId: id,
        family: 'capability',
        codeReferences: codeReferences,
        benchmarkScenes: const <String>['capability_baseline_scene'],
      ),
      benchmarkDecision: benchmarkDecision,
      legacyPathCleanup: _defaultCleanupDecisionMap(),
      supportedEntrySurfaces: _defaultEntrySurfaces,
      failureMode: 'blocked',
    );
  }

  static CapabilityBenchmarkRecord _benchmark({
    required String capabilityId,
    required String family,
    required List<String> codeReferences,
    required List<String> benchmarkScenes,
  }) {
    return CapabilityBenchmarkRecord(
      capabilityId: capabilityId,
      capabilityFamily: family,
      benchmarkVersion: 'v1',
      comparedAgainst: const <String>['refusion', 'remotion', 'hyperframes'],
      visualQuality: 4,
      temporalAccuracy: 4,
      parameterDepth: 4,
      performance: 4,
      previewExportParity: 4,
      editability: 4,
      determinism: 4,
      crossDeviceStability: 4,
      pipelineCoverage: 4,
      agentUsability: 4,
      codeReferences: codeReferences,
      benchmarkScenes: benchmarkScenes,
      measurementResults: const <String>['pending:baseline-metrics-v1'],
    );
  }

  static Map<String, LegacyPathCleanupDecision> _defaultCleanupDecisionMap() {
    return const <String, LegacyPathCleanupDecision>{
      'manualUiPath': LegacyPathCleanupDecision.canonicalize,
      'mcpPath': LegacyPathCleanupDecision.canonicalize,
      'pasteScriptPath': LegacyPathCleanupDecision.adapterOnly,
      'templatePath': LegacyPathCleanupDecision.canonicalize,
      'tapListPath': LegacyPathCleanupDecision.adapterOnly,
      'legacyLocalMutationPath': LegacyPathCleanupDecision.migrate,
      'rendererOnlyPath': LegacyPathCleanupDecision.canonicalize,
      'databaseOnlyPath': LegacyPathCleanupDecision.block,
      'metadataOnlyPath': LegacyPathCleanupDecision.delete,
      'exportOnlyPath': LegacyPathCleanupDecision.canonicalize,
    };
  }

  static int _durationTokenMs(String token) {
    switch (token) {
      case r'$duration.fast':
        return 420;
      case r'$duration.medium':
        return 680;
      case r'$duration.slow':
        return 1000;
      default:
        return 680;
    }
  }

  static String _camelToToken(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i += 1) {
      final char = value[i];
      final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
      if (isUpper && i > 0) {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }
}

const RendererConformanceDefinition _defaultRendererConformance =
    RendererConformanceDefinition(
  previewSupported: true,
  exportSupported: true,
  deterministic: true,
  rendererPath:
      'lib/features/editor/domain/services/trueframe_core_runtime_evaluator.dart',
  exportPath:
      'lib/features/editor/domain/models/export_composition_models.dart',
  fallbackMode: 'blocked',
);

const RendererConformanceDefinition _defaultExportConformance =
    RendererConformanceDefinition(
  previewSupported: true,
  exportSupported: true,
  deterministic: true,
  rendererPath:
      'lib/features/editor/domain/services/master_render_graph_adapter.dart',
  exportPath:
      'lib/features/editor/domain/models/export_composition_models.dart',
  fallbackMode: 'blocked',
);

const Set<SupportedEntrySurface> _defaultEntrySurfaces =
    <SupportedEntrySurface>{
  SupportedEntrySurface.manualUi,
  SupportedEntrySurface.mcp,
  SupportedEntrySurface.pasteScript,
  SupportedEntrySurface.template,
  SupportedEntrySurface.tapList,
  SupportedEntrySurface.futureTool,
};
