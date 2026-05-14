import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/services/mcp_effect_capability_guard.dart';

void main() {
  const guard = McpEffectCapabilityGuard();

  group('McpEffectCapabilityGuard', () {
    test('returns no blockers for supported effect payloads', () {
      final remoteLayers = <Map<String, Object?>>[
        <String, Object?>{
          'id': 'layer-1',
          'payload': <String, Object?>{
            'effects': <Object?>[
              <String, Object?>{'type': 'mask'},
              <String, Object?>{'type': 'border'},
              <String, Object?>{'type': 'glow'},
            ],
          },
        },
      ];

      final blockers = guard.detectUnsupportedEffects(remoteLayers);
      expect(blockers, isEmpty);
    });

    test('flags unsupported effect in direct payload effect map', () {
      final remoteLayers = <Map<String, Object?>>[
        <String, Object?>{
          'id': 'layer-2',
          'payload': <String, Object?>{
            'effect': <String, Object?>{'type': 'vignette'},
          },
        },
      ];

      final blockers = guard.detectUnsupportedEffects(remoteLayers);
      expect(blockers.length, 1);
      expect(blockers.first.code, 'UNSUPPORTED_EFFECT_CAPABILITY');
      expect(blockers.first.effectType, 'vignette');
      expect(blockers.first.layerId, 'layer-2');
    });

    test('reads nested updates payload effect list and normalizes names', () {
      final remoteLayers = <Map<String, Object?>>[
        <String, Object?>{
          'id': 'layer-3',
          'payload': <String, Object?>{
            'updates': <String, Object?>{
              'payload': <String, Object?>{
                'effects': <Object?>[
                  <String, Object?>{'id': 'chromatic aberration'},
                  <String, Object?>{'effectType': 'motion-blur'},
                ],
              },
            },
          },
        },
      ];

      final blockers = guard.detectUnsupportedEffects(remoteLayers);
      expect(blockers.length, 1);
      expect(blockers.first.effectType, 'chromatic_aberration');
      expect(blockers.first.layerId, 'layer-3');
    });

    test('supports string effect forms and deduplicates blockers', () {
      final remoteLayers = <Map<String, Object?>>[
        <String, Object?>{
          'id': 'layer-4',
          'payload': <String, Object?>{
            'effects': <Object?>[
              'film grain',
              'film_grain',
              'mask',
            ],
          },
        },
      ];

      final blockers = guard.detectUnsupportedEffects(remoteLayers);
      expect(blockers.length, 1);
      expect(blockers.first.effectType, 'film_grain');
    });

    test('inspectCapabilities returns proof-friendly capability matrix', () {
      final remoteLayers = <Map<String, Object?>>[
        <String, Object?>{
          'id': 'layer-a',
          'payload': <String, Object?>{
            'effects': <Object?>[
              <String, Object?>{'type': 'mask'},
              <String, Object?>{'type': 'glow'},
            ],
          },
        },
        <String, Object?>{
          'id': 'layer-b',
          'payload': <String, Object?>{
            'effect': <String, Object?>{'type': 'vignette'},
          },
        },
      ];

      final report = guard.inspectCapabilities(remoteLayers);
      expect(report.detectedEffectTypes,
          containsAll(<String>['mask', 'glow', 'vignette']));
      expect(
          report.supportedEffectTypes, containsAll(<String>['mask', 'glow']));
      expect(report.unsupportedEffectTypes, <String>['vignette']);
      expect(report.blockers.length, 1);

      final proof = report.toProofMap();
      expect(proof['effectCapability.blockerCount'], 1);
      expect(proof['effectCapability.unsupported'], <String>['vignette']);
      expect(proof['effectCapability.layerEffectTypes'], isNotEmpty);
    });
  });
}
