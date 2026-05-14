import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/services/mcp_universal_layer_identity.dart';

void main() {
  group('UniversalMcpLayerIdentityResolver', () {
    const resolver = UniversalMcpLayerIdentityResolver();

    test('resolves single candidate by explicit targetLayerId', () {
      final resolution = resolver.resolve(
        remoteLayerId: 'remote-1',
        payload: const <String, Object?>{'targetLayerId': 'layer-1'},
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
        exists: (id) => id == 'layer-1',
        targetKind: UniversalLayerTargetKind.textElement,
        targetFamily: 'text',
      );
      expect(
        resolution.result,
        UniversalLayerResolutionResult.resolvedSingle,
      );
      expect(resolution.target?.canonicalTargetId, 'layer-1');
    });

    test('returns ambiguous when multiple candidates resolve', () {
      final resolution = resolver.resolve(
        remoteLayerId: 'remote-1',
        payload: const <String, Object?>{
          'targetLayerId': 'layer-1',
          'layerId': 'layer-2',
        },
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
        exists: (id) => id == 'layer-1' || id == 'layer-2',
        failOnAmbiguity: true,
      );
      expect(
        resolution.result,
        UniversalLayerResolutionResult.resolvedAmbiguous,
      );
      expect(resolution.target?.isAmbiguous, isTrue);
    });

    test('returns missing target when nothing resolves', () {
      final resolution = resolver.resolve(
        remoteLayerId: 'remote-missing',
        payload: const <String, Object?>{},
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
        exists: (_) => false,
      );
      expect(
        resolution.result,
        UniversalLayerResolutionResult.missingTarget,
      );
      expect(resolution.target?.isMissing, isTrue);
    });
  });

  group('UniversalLayerApplyIntentClassifier', () {
    const classifier = UniversalLayerApplyIntentClassifier();

    test('classifies insert when no target/mutation hints exist', () {
      final intent = classifier.classify(
        payload: const <String, Object?>{'operation': 'insert_layer'},
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
      );
      expect(intent, UniversalLayerApplyIntent.insert);
    });

    test('classifies update for insert_layer carrying targetLayerId', () {
      final intent = classifier.classify(
        payload: const <String, Object?>{
          'operation': 'insert_layer',
          'targetLayerId': 'layer-1',
        },
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
      );
      expect(intent, UniversalLayerApplyIntent.update);
    });

    test('classifies motion mutation when motion payload exists', () {
      final intent = classifier.classify(
        payload: const <String, Object?>{
          'motion': <String, Object?>{
            'in': <String, Object?>{'preset': 'popUp'},
          },
        },
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
      );
      expect(intent, UniversalLayerApplyIntent.motionMutation);
    });

    test(
        'keeps insert intent for insert_layer with style payload and no target',
        () {
      final intent = classifier.classify(
        payload: const <String, Object?>{
          'operation': 'insert_layer',
          'style': <String, Object?>{
            'fill': '#FFFFFF',
          },
        },
        updates: const <String, Object?>{
          'style': <String, Object?>{
            'fill': '#FFFFFF',
          },
        },
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
      );
      expect(intent, UniversalLayerApplyIntent.insert);
    });

    test(
        'classifies style mutation when style payload has explicit target hints',
        () {
      final intent = classifier.classify(
        payload: const <String, Object?>{
          'operation': 'insert_layer',
          'targetLayerId': 'shape-1',
          'style': <String, Object?>{
            'fill': '#FF0000',
          },
        },
        updates: const <String, Object?>{},
        payloadPayload: const <String, Object?>{},
        updatesPayload: const <String, Object?>{},
      );
      expect(intent, UniversalLayerApplyIntent.styleMutation);
    });
  });
}
