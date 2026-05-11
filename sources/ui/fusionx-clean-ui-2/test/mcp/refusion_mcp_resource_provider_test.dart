import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_resource_provider.dart';

void main() {
  group('RefusionMcpResourceProvider', () {
    test('returns registered resources', () {
      final provider = RefusionMcpResourceProvider(
        readers: <String, RefusionMcpResourceReader>{
          'refusion://project/active/state': () => <String, Object?>{
                'projectId': 'active',
                'revision': 41,
              },
        },
      );
      final result = provider.read('refusion://project/active/state');
      expect(result.ok, isTrue);
      expect(result.payload['projectId'], 'active');
      expect(result.payload['revision'], 41);
    });

    test('returns unknown resource failure for missing uri', () {
      final provider = RefusionMcpResourceProvider();
      final result = provider.read('refusion://unknown');
      expect(result.ok, isFalse);
      expect(result.code, RefusionMcpResourceCode.unknownResource);
    });

    test('returns unavailable failure when resource reader returns null', () {
      final provider = RefusionMcpResourceProvider(
        readers: <String, RefusionMcpResourceReader>{
          'refusion://preview/frame/latest': () => null,
        },
      );
      final result = provider.read('refusion://preview/frame/latest');
      expect(result.ok, isFalse);
      expect(result.code, RefusionMcpResourceCode.unavailableResource);
    });

    test('returns too large failure when payload exceeds size limit', () {
      final provider = RefusionMcpResourceProvider(
        maxPayloadBytes: 10,
        readers: <String, RefusionMcpResourceReader>{
          'refusion://oversized': () => <String, Object?>{
                'payload': 'this-is-way-too-large',
              },
        },
      );
      final result = provider.read('refusion://oversized');
      expect(result.ok, isFalse);
      expect(result.code, RefusionMcpResourceCode.resourceTooLarge);
    });
  });
}
