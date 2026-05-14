import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/creative_transaction_contract_models.dart';
import 'package:refusion_app/features/editor/domain/services/creative_target_resolver.dart';

void main() {
  group('CreativeTargetResolver', () {
    const resolver = CreativeTargetResolver();

    test('remoteLayerId alias resolves to canonical layerId', () {
      final layers = <CreativeLayerIdentity>[
        _layer(
          'layer-text-1',
          aliases: const <CreativeLayerAlias>[
            CreativeLayerAlias(kind: 'remoteLayerId', value: 'remote-text-1'),
          ],
        ),
      ];

      final resolution = resolver.resolve(
        CreativeTargetResolutionRequest(
          layers: layers,
          target: const CreativeTargetRef(layerAlias: 'remote-text-1'),
        ),
      );

      expect(resolution.result, CreativeTargetResolutionResult.resolvedSingle);
      expect(resolution.layerId, 'layer-text-1');
      expect(resolution.resolutionSource, 'aliasExactMatch');
    });

    test('text targetLayerId resolves after previous insert', () {
      final layers = <CreativeLayerIdentity>[
        _layer('layer-text-2'),
      ];
      final resolution = resolver.resolve(
        CreativeTargetResolutionRequest(
          layers: layers,
          target: const CreativeTargetRef(layerId: 'layer-text-2'),
          transactionCreatedLayerId: 'layer-text-2',
        ),
      );
      expect(resolution.result, CreativeTargetResolutionResult.resolvedSingle);
      expect(resolution.layerId, 'layer-text-2');
      expect(resolution.resolutionSource, 'canonicalLayerId');
    });

    test('ambiguous same text blocks', () {
      final layers = <CreativeLayerIdentity>[
        _layer('text-a'),
        _layer('text-b'),
      ];
      final resolution = resolver.resolve(
        CreativeTargetResolutionRequest(
          layers: layers,
          textQuery: 'TEST',
          textByLayerId: const <String, String>{
            'text-a': 'test',
            'text-b': 'test',
          },
        ),
      );
      expect(
        resolution.result,
        CreativeTargetResolutionResult.resolvedAmbiguous,
      );
      expect(
        resolution.ambiguity?.candidateLayerIds,
        containsAll(<String>['text-a', 'text-b']),
      );
    });

    test('missing update target blocks', () {
      final resolution = resolver.resolve(
        const CreativeTargetResolutionRequest(
          layers: <CreativeLayerIdentity>[],
          target: CreativeTargetRef(layerId: 'missing-layer'),
        ),
      );
      expect(resolution.result, CreativeTargetResolutionResult.missingTarget);
    });

    test('selected fallback blocks unless explicitly requested', () {
      final layers = <CreativeLayerIdentity>[_layer('shape-1')];
      final blocked = resolver.resolve(
        CreativeTargetResolutionRequest(
          layers: layers,
          selectedLayerIds: const <String>['shape-1'],
          allowSelectedFallback: false,
        ),
      );
      expect(
        blocked.result,
        CreativeTargetResolutionResult.blockedUnsafeFallback,
      );

      final allowed = resolver.resolve(
        CreativeTargetResolutionRequest(
          layers: layers,
          selectedLayerIds: const <String>['shape-1'],
          allowSelectedFallback: true,
        ),
      );
      expect(allowed.result, CreativeTargetResolutionResult.resolvedSingle);
      expect(allowed.layerId, 'shape-1');
      expect(allowed.resolutionSource, 'selectedLayer');
    });

    test('spatial query with one result resolves', () {
      final layers = <CreativeLayerIdentity>[
        _layer('shape-1'),
        _layer('shape-2'),
      ];
      final resolution = resolver.resolve(
        CreativeTargetResolutionRequest(
          layers: layers,
          spatialCandidateLayerIds: const <String>['shape-2'],
        ),
      );
      expect(resolution.result, CreativeTargetResolutionResult.resolvedSingle);
      expect(resolution.layerId, 'shape-2');
      expect(resolution.resolutionSource, 'spatialSingleMatch');
    });

    test('spatial query with multiple results blocks as ambiguous', () {
      final layers = <CreativeLayerIdentity>[
        _layer('shape-1'),
        _layer('shape-2'),
      ];
      final resolution = resolver.resolve(
        CreativeTargetResolutionRequest(
          layers: layers,
          spatialCandidateLayerIds: const <String>['shape-1', 'shape-2'],
        ),
      );
      expect(
        resolution.result,
        CreativeTargetResolutionResult.resolvedAmbiguous,
      );
      expect(
        resolution.ambiguity?.candidateLayerIds,
        containsAll(<String>['shape-1', 'shape-2']),
      );
    });
  });
}

CreativeLayerIdentity _layer(
  String id, {
  List<CreativeLayerAlias> aliases = const <CreativeLayerAlias>[],
}) {
  return CreativeLayerIdentity(
    layerId: id,
    kind: 'shape',
    compositionId: 'composition-1',
    timelineTrackId: 'shape',
    zOrder: 0,
    createdBy: CreativeTransactionSource.manualUi,
    createdAtRevision: 1,
    updatedAtRevision: 1,
    aliases: aliases,
  );
}
