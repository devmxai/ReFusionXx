import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/services/mcp_effect_payload_lowering.dart';

void main() {
  const lowering = McpEffectPayloadLowering();

  group('McpEffectPayloadLowering', () {
    test('lowers mask effect to circle mask and radius', () {
      final result = lowering.lower(
        payload: <String, Object?>{
          'effects': <Object?>[
            <String, Object?>{
              'type': 'mask',
              'params': <String, Object?>{
                'shape': 'circle',
                'radius': 240,
              },
            },
          ],
        },
        updates: const <String, Object?>{},
      );

      expect(result.hasAny, isTrue);
      expect(result.circleMask, isTrue);
      expect(result.cornerRadius, 240);
    });

    test('lowers border and glow effects', () {
      final result = lowering.lower(
        payload: <String, Object?>{
          'effects': <Object?>[
            <String, Object?>{
              'type': 'border',
              'params': <String, Object?>{
                'width': 6,
                'color': '#FFFFFF',
              },
            },
            <String, Object?>{
              'type': 'glow',
              'params': <String, Object?>{
                'blur': 18,
                'opacity': 0.22,
                'color': '#88CCFF',
              },
            },
          ],
        },
        updates: const <String, Object?>{},
      );

      expect(result.borderWidth, 6);
      expect(result.borderColorHex, '#FFFFFF');
      expect(result.glowBlur, 18);
      expect(result.glowOpacity, 0.22);
      expect(result.glowColorHex, '#88CCFF');
    });

    test('lowers transform effect to center/scale/rotation', () {
      final result = lowering.lower(
        payload: <String, Object?>{
          'effects': <Object?>[
            <String, Object?>{
              'type': 'transform',
              'params': <String, Object?>{
                'x': 860,
                'y': 260,
                'scale': 0.42,
                'rotation': 12,
              },
            },
          ],
        },
        updates: const <String, Object?>{},
      );

      expect(result.centerX, 860);
      expect(result.centerY, 260);
      expect(result.scaleX, 0.42);
      expect(result.scaleY, 0.42);
      expect(result.rotationDegrees, 12);
    });

    test('reads nested updates payload effects', () {
      final result = lowering.lower(
        payload: const <String, Object?>{},
        updates: <String, Object?>{
          'payload': <String, Object?>{
            'effects': <Object?>[
              <String, Object?>{
                'effectType': 'border',
                'params': <String, Object?>{
                  'strokeWidth': 4,
                  'strokeColor': '#00FF00',
                },
              },
            ],
          },
        },
      );

      expect(result.borderWidth, 4);
      expect(result.borderColorHex, '#00FF00');
    });
  });
}
