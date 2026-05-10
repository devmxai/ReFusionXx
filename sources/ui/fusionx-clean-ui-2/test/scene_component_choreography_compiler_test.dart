import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_director_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_component_choreography_compiler.dart';
import 'package:refusion_app/features/editor/domain/services/scene_component_choreography_models.dart';

void main() {
  const compiler = SceneComponentChoreographyCompiler();

  test('compiles PromptInputBar choreography deterministically', () {
    final request = SceneComponentChoreographyCompileRequest(
      componentType: 'PromptInputBar',
      beatId: 'intro',
      parentStartMs: 0,
      parentEndMs: 2200,
      componentIdsByRole: const <String, String>{
        'shell': 'prompt-shell',
        'plus': 'prompt-plus',
        'mic': 'prompt-mic',
        'voice': 'prompt-voice',
        'text': 'prompt-text',
        'send': 'prompt-send',
      },
      requiredRoles: const <String>{
        'shell',
        'plus',
        'mic',
        'voice',
        'text',
        'send'
      },
      spans: const <SceneComponentChoreographySpan>[
        SceneComponentChoreographySpan(
          role: 'shell',
          targetScope: 'cardShell',
          recipeId: r'$motion.popInSpring',
          startMs: 0,
          endMs: 520,
          phase: 'enter',
        ),
        SceneComponentChoreographySpan(
          role: 'plus',
          targetScope: 'icon',
          recipeId: r'$motion.iconPop',
          startMs: 120,
          endMs: 560,
          phase: 'internalReveal',
        ),
        SceneComponentChoreographySpan(
          role: 'mic',
          targetScope: 'icon',
          recipeId: r'$motion.iconPop',
          startMs: 170,
          endMs: 620,
          phase: 'internalReveal',
        ),
        SceneComponentChoreographySpan(
          role: 'voice',
          targetScope: 'icon',
          recipeId: r'$motion.iconPop',
          startMs: 220,
          endMs: 640,
          phase: 'internalReveal',
        ),
        SceneComponentChoreographySpan(
          role: 'text',
          targetScope: 'body',
          recipeId: r'$motion.typewriterFixedFrame',
          startMs: 260,
          endMs: 980,
          phase: 'action',
        ),
        SceneComponentChoreographySpan(
          role: 'send',
          targetScope: 'button',
          recipeId: r'$motion.sendPress',
          startMs: 980,
          endMs: 1180,
          phase: 'action',
        ),
        SceneComponentChoreographySpan(
          role: 'plus',
          targetScope: 'button',
          recipeId: r'$motion.plusPressToFill',
          startMs: 1180,
          endMs: 1660,
          phase: 'action',
        ),
        SceneComponentChoreographySpan(
          role: 'shell',
          targetScope: 'cardShell',
          recipeId: r'$motion.pushBack',
          startMs: 1700,
          endMs: 2200,
          phase: 'exit',
        ),
        SceneComponentChoreographySpan(
          role: 'mic',
          targetScope: 'icon',
          recipeId: r'$motion.scaleOut',
          startMs: 1700,
          endMs: 2140,
          phase: 'exit',
        ),
        SceneComponentChoreographySpan(
          role: 'voice',
          targetScope: 'icon',
          recipeId: r'$motion.scaleOut',
          startMs: 1720,
          endMs: 2140,
          phase: 'exit',
        ),
        SceneComponentChoreographySpan(
          role: 'text',
          targetScope: 'text',
          recipeId: r'$motion.fadeCollapse',
          startMs: 1740,
          endMs: 2140,
          phase: 'exit',
        ),
        SceneComponentChoreographySpan(
          role: 'send',
          targetScope: 'button',
          recipeId: r'$motion.scaleOut',
          startMs: 1730,
          endMs: 2140,
          phase: 'exit',
        ),
      ],
    );

    final first = compiler.compile(request);
    final second = compiler.compile(request);

    expect(first.isValid, isTrue, reason: _errorMessages(first));
    expect(second.isValid, isTrue, reason: _errorMessages(second));
    expect(
      first.issues.any(
        (issue) =>
            issue.message.contains(kSceneComponentChoreographyCompilerProofTag),
      ),
      isTrue,
    );
    expect(_primitiveSignature(first.primitives),
        _primitiveSignature(second.primitives));
  });

  test('compiles FeatureCard and CTAButton choreography deterministically', () {
    final feature = compiler.compile(
      SceneComponentChoreographyCompileRequest(
        componentType: 'FeatureCard',
        beatId: 'features',
        parentStartMs: 700,
        parentEndMs: 3100,
        componentIdsByRole: const <String, String>{
          'shell': 'feature-shell',
          'icon': 'feature-icon',
          'label': 'feature-label',
          'body': 'feature-body',
        },
        requiredRoles: const <String>{'shell', 'icon', 'label', 'body'},
        spans: const <SceneComponentChoreographySpan>[
          SceneComponentChoreographySpan(
            role: 'shell',
            targetScope: 'cardShell',
            recipeId: r'$motion.cardSpringEntrance',
            startMs: 700,
            endMs: 1300,
            phase: 'enter',
          ),
          SceneComponentChoreographySpan(
            role: 'icon',
            targetScope: 'icon',
            recipeId: r'$motion.iconPop',
            startMs: 790,
            endMs: 1380,
            phase: 'internalReveal',
          ),
          SceneComponentChoreographySpan(
            role: 'label',
            targetScope: 'body',
            recipeId: r'$motion.wordCascadeUp',
            startMs: 860,
            endMs: 1480,
            phase: 'internalReveal',
          ),
          SceneComponentChoreographySpan(
            role: 'body',
            targetScope: 'body',
            recipeId: r'$motion.wordCascadeUp',
            startMs: 920,
            endMs: 1620,
            phase: 'internalReveal',
          ),
          SceneComponentChoreographySpan(
            role: 'shell',
            targetScope: 'cardShell',
            recipeId: r'$motion.pushBack',
            startMs: 2500,
            endMs: 3100,
            phase: 'exit',
          ),
          SceneComponentChoreographySpan(
            role: 'icon',
            targetScope: 'icon',
            recipeId: r'$motion.scaleOut',
            startMs: 2520,
            endMs: 3080,
            phase: 'exit',
          ),
          SceneComponentChoreographySpan(
            role: 'label',
            targetScope: 'text',
            recipeId: r'$motion.fadeCollapse',
            startMs: 2540,
            endMs: 3080,
            phase: 'exit',
          ),
          SceneComponentChoreographySpan(
            role: 'body',
            targetScope: 'text',
            recipeId: r'$motion.fadeCollapse',
            startMs: 2560,
            endMs: 3080,
            phase: 'exit',
          ),
        ],
      ),
    );

    final cta = compiler.compile(
      SceneComponentChoreographyCompileRequest(
        componentType: 'CTAButton',
        beatId: 'outro',
        parentStartMs: 2400,
        parentEndMs: 3600,
        componentIdsByRole: const <String, String>{
          'shell': 'cta-shell',
          'label': 'cta-label',
          'trailingIcon': 'cta-icon',
        },
        requiredRoles: const <String>{'shell', 'label', 'trailingIcon'},
        spans: const <SceneComponentChoreographySpan>[
          SceneComponentChoreographySpan(
            role: 'shell',
            targetScope: 'cardShell',
            recipeId: r'$motion.popInSpring',
            startMs: 2400,
            endMs: 2840,
            phase: 'enter',
          ),
          SceneComponentChoreographySpan(
            role: 'label',
            targetScope: 'text',
            recipeId: r'$motion.wordCascadeUp',
            startMs: 2480,
            endMs: 2920,
            phase: 'internalReveal',
          ),
          SceneComponentChoreographySpan(
            role: 'trailingIcon',
            targetScope: 'icon',
            recipeId: r'$motion.iconPop',
            startMs: 2520,
            endMs: 2960,
            phase: 'internalReveal',
          ),
          SceneComponentChoreographySpan(
            role: 'shell',
            targetScope: 'cardShell',
            recipeId: r'$motion.pushBack',
            startMs: 3200,
            endMs: 3600,
            phase: 'exit',
          ),
          SceneComponentChoreographySpan(
            role: 'label',
            targetScope: 'text',
            recipeId: r'$motion.fadeCollapse',
            startMs: 3240,
            endMs: 3580,
            phase: 'exit',
          ),
          SceneComponentChoreographySpan(
            role: 'trailingIcon',
            targetScope: 'icon',
            recipeId: r'$motion.scaleOut',
            startMs: 3260,
            endMs: 3580,
            phase: 'exit',
          ),
        ],
      ),
    );

    expect(feature.isValid, isTrue, reason: _errorMessages(feature));
    expect(cta.isValid, isTrue, reason: _errorMessages(cta));
    expect(feature.primitives, isNotEmpty);
    expect(cta.primitives, isNotEmpty);
  });

  test('emits strict fatal errors for invalid choreography semantics', () {
    final overlap = compiler.compile(
      SceneComponentChoreographyCompileRequest(
        componentType: 'FeatureCard',
        beatId: 'features',
        parentStartMs: 100,
        parentEndMs: 900,
        componentIdsByRole: const <String, String>{'shell': 'feature-shell'},
        spans: const <SceneComponentChoreographySpan>[
          SceneComponentChoreographySpan(
            role: 'shell',
            targetScope: 'cardShell',
            recipeId: r'$motion.scaleIn',
            startMs: 100,
            endMs: 620,
            phase: 'enter',
          ),
          SceneComponentChoreographySpan(
            role: 'shell',
            targetScope: 'cardShell',
            recipeId: r'$motion.popInSpring',
            startMs: 300,
            endMs: 780,
            phase: 'action',
          ),
        ],
      ),
    );
    expect(
      overlap.issues
          .any((issue) => issue.message.contains('DUPLICATE_CHANNEL_OVERLAP')),
      isTrue,
    );

    final outsideParent = compiler.compile(
      SceneComponentChoreographyCompileRequest(
        componentType: 'PromptInputBar',
        beatId: 'intro',
        parentStartMs: 0,
        parentEndMs: 600,
        componentIdsByRole: const <String, String>{'shell': 'prompt-shell'},
        spans: const <SceneComponentChoreographySpan>[
          SceneComponentChoreographySpan(
            role: 'shell',
            targetScope: 'cardShell',
            recipeId: r'$motion.popInSpring',
            startMs: -40,
            endMs: 520,
            phase: 'enter',
          ),
        ],
      ),
    );
    expect(
      outsideParent.issues.any(
          (issue) => issue.message.contains('CHILD_TIMING_OUTSIDE_PARENT')),
      isTrue,
    );

    final incoherentExit = compiler.compile(
      SceneComponentChoreographyCompileRequest(
        componentType: 'CTAButton',
        beatId: 'outro',
        parentStartMs: 1200,
        parentEndMs: 2200,
        componentIdsByRole: const <String, String>{
          'shell': 'cta-shell',
          'trailingIcon': 'cta-icon',
        },
        requiredRoles: const <String>{'shell', 'label', 'trailingIcon'},
        spans: const <SceneComponentChoreographySpan>[
          SceneComponentChoreographySpan(
            role: 'shell',
            targetScope: 'cardShell',
            recipeId: r'$motion.pushBack',
            startMs: 1200,
            endMs: 1400,
            phase: 'exit',
          ),
          SceneComponentChoreographySpan(
            role: 'trailingIcon',
            targetScope: 'icon',
            recipeId: r'$motion.scaleOut',
            startMs: 1700,
            endMs: 2200,
            phase: 'exit',
          ),
        ],
      ),
    );
    expect(
      incoherentExit.issues
          .any((issue) => issue.message.contains('GROUP_EXIT_INCOHERENT')),
      isTrue,
    );

    final fadeOnly = compiler.compile(
      SceneComponentChoreographyCompileRequest(
        componentType: 'FeatureCard',
        beatId: 'outro',
        parentStartMs: 1500,
        parentEndMs: 2400,
        componentIdsByRole: const <String, String>{
          'shell': 'feature-shell',
          'label': 'feature-label',
        },
        spans: const <SceneComponentChoreographySpan>[
          SceneComponentChoreographySpan(
            role: 'shell',
            targetScope: 'cardShell',
            recipeId: r'$motion.fadeCollapse',
            startMs: 1700,
            endMs: 2200,
            phase: 'exit',
          ),
          SceneComponentChoreographySpan(
            role: 'label',
            targetScope: 'text',
            recipeId: r'$motion.fadeCollapse',
            startMs: 1740,
            endMs: 2240,
            phase: 'exit',
          ),
        ],
      ),
    );
    expect(
      fadeOnly.issues.any(
          (issue) => issue.message.contains('FADE_ONLY_PROFESSIONAL_RECIPE')),
      isTrue,
    );
  });
}

List<String> _primitiveSignature(
    List<ReFusionMotionDirectorPrimitive> primitives) {
  return primitives
      .map(
        (primitive) => [
          primitive.id,
          primitive.targetComponentId,
          primitive.kind,
          primitive.property ?? '',
          primitive.startMs.toString(),
          primitive.endMs.toString(),
          primitive.easing,
        ].join('|'),
      )
      .toList(growable: false);
}

String _errorMessages(SceneComponentChoreographyCompileResult result) {
  return result.issues
      .where(
        (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
      )
      .map((issue) => issue.message)
      .join(' | ');
}
