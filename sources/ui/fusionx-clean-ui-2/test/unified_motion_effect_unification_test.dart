import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/creative_transaction_contract_models.dart';
import 'package:refusion_app/features/editor/domain/services/unified_creative_apply_engine.dart';

void main() {
  group('PIVWSCT-09 motion/effect/keyframe unification', () {
    const engine = UnifiedCreativeApplyEngine();
    const context = CreativeApplyContext(
      projectId: 'project-1',
      compositionSpec: CreativeCompositionSpec(
        compositionId: 'story-1',
        width: 1080,
        height: 1920,
        fps: 30,
        durationMs: 8000,
        currentTimeMs: 0,
        currentFrame: 0,
        coordinateSystem: 'center',
        origin: 'canvasCenter',
      ),
      currentRevision: 0,
      rendererCapabilities: <String>{'motion', 'effects'},
    );

    test('manual shape move then MCP motion starts from moved position', () {
      final inserted = engine.apply(
        state: _state(),
        context: context,
        transaction: _tx(
          id: 'shape-insert',
          intent: CreativeTransactionIntent.shapeInsert,
          target: const CreativeTargetRef(layerId: 'shape-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(kind: 'shape.insert'),
          ],
        ),
      );
      final moved = engine.apply(
        state: inserted.state,
        context: context,
        transaction: _tx(
          id: 'shape-move',
          baseRevision: inserted.state.revision,
          intent: CreativeTransactionIntent.transformPatch,
          target: const CreativeTargetRef(layerId: 'shape-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'transform.patch',
              payload: <String, Object?>{'x': 444},
            ),
          ],
        ),
      );
      final motion = engine.apply(
        state: moved.state,
        context: context,
        transaction: _tx(
          id: 'shape-motion',
          baseRevision: moved.state.revision,
          intent: CreativeTransactionIntent.keyframeBatchApply,
          target: const CreativeTargetRef(layerId: 'shape-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'keyframe.batch_apply',
              payload: <String, Object?>{'propertyId': 'x', 'keyframes': <Object?>[]},
            ),
          ],
        ),
      );

      final node = motion.state.layers['shape-1']!;
      final xChannel = node.motionChannels.firstWhere(
        (channel) => channel.propertyId == 'x',
      );
      expect(xChannel.keyframes.first.value, 444);
    });

    test('MCP text pop animation updates same text target', () {
      final inserted = engine.apply(
        state: _state(),
        context: context,
        transaction: _tx(
          id: 'text-insert',
          intent: CreativeTransactionIntent.textInsert,
          target: const CreativeTargetRef(layerId: 'text-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'text.insert',
              payload: <String, Object?>{'text': 'hello'},
            ),
          ],
        ),
      );
      final animated = engine.apply(
        state: inserted.state,
        context: context,
        transaction: _tx(
          id: 'text-animate',
          baseRevision: inserted.state.revision,
          intent: CreativeTransactionIntent.animationApplyRecipe,
          target: const CreativeTargetRef(layerId: 'text-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'animation.apply_recipe',
              payload: <String, Object?>{'recipeId': 'popUp'},
            ),
          ],
        ),
      );

      expect(animated.success, isTrue);
      expect(animated.state.layers.length, 1);
      expect(animated.state.layers['text-1']!.motionChannels, isNotEmpty);
    });

    test('effect apply updates existing effect entry unless explicit stacked', () {
      final inserted = engine.apply(
        state: _state(),
        context: context,
        transaction: _tx(
          id: 'shape-insert',
          intent: CreativeTransactionIntent.shapeInsert,
          target: const CreativeTargetRef(layerId: 'shape-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(kind: 'shape.insert'),
          ],
        ),
      );
      final firstEffect = engine.apply(
        state: inserted.state,
        context: context,
        transaction: _tx(
          id: 'effect-1',
          baseRevision: inserted.state.revision,
          intent: CreativeTransactionIntent.effectApply,
          target: const CreativeTargetRef(layerId: 'shape-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'effect.apply',
              payload: <String, Object?>{'effectType': 'glow', 'radius': 12},
            ),
          ],
        ),
      );
      final secondEffect = engine.apply(
        state: firstEffect.state,
        context: context,
        transaction: _tx(
          id: 'effect-2',
          baseRevision: firstEffect.state.revision,
          intent: CreativeTransactionIntent.effectApply,
          target: const CreativeTargetRef(layerId: 'shape-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'effect.apply',
              payload: <String, Object?>{'effectType': 'glow', 'radius': 20},
            ),
          ],
        ),
      );

      final effects = secondEffect.state.layers['shape-1']!.effectStack;
      expect(effects.length, 1);
      expect(effects.single.params['radius'], 20);

      final stacked = engine.apply(
        state: secondEffect.state,
        context: context,
        transaction: _tx(
          id: 'effect-3',
          baseRevision: secondEffect.state.revision,
          intent: CreativeTransactionIntent.effectApply,
          target: const CreativeTargetRef(layerId: 'shape-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'effect.apply',
              payload: <String, Object?>{
                'effectType': 'glow',
                'radius': 26,
                'explicitStack': true,
              },
            ),
          ],
        ),
      );
      expect(stacked.state.layers['shape-1']!.effectStack.length, 2);
    });

    test('unknown recipe fails closed', () {
      final inserted = engine.apply(
        state: _state(),
        context: context,
        transaction: _tx(
          id: 'text-insert',
          intent: CreativeTransactionIntent.textInsert,
          target: const CreativeTargetRef(layerId: 'text-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'text.insert',
              payload: <String, Object?>{'text': 'hello'},
            ),
          ],
        ),
      );
      final failed = engine.apply(
        state: inserted.state,
        context: context,
        transaction: _tx(
          id: 'text-animate-invalid',
          baseRevision: inserted.state.revision,
          intent: CreativeTransactionIntent.animationApplyRecipe,
          target: const CreativeTargetRef(layerId: 'text-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'animation.apply_recipe',
              payload: <String, Object?>{'recipeId': 'unknown-recipe'},
            ),
          ],
        ),
      );
      expect(failed.success, isFalse);
      expect(failed.error, contains('UNKNOWN_MOTION_RECIPE'));
      expect(failed.state.revision, inserted.state.revision);
    });
  });
}

UnifiedCreativeState _state() {
  return const UnifiedCreativeState(
    projectId: 'project-1',
    compositionId: 'story-1',
    revision: 0,
  );
}

CreativeTransactionEnvelope _tx({
  required String id,
  required CreativeTransactionIntent intent,
  int baseRevision = 0,
  CreativeTargetRef? target,
  required List<CreativeTransactionOperation> operations,
}) {
  return CreativeTransactionEnvelope(
    transactionId: id,
    schemaVersion: 1,
    source: CreativeTransactionSource.mcpAgent,
    intent: intent,
    projectId: 'project-1',
    compositionId: 'story-1',
    baseRevision: baseRevision,
    target: target,
    operations: operations,
  );
}
