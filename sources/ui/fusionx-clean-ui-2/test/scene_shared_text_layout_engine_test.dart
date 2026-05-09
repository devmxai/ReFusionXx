import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/scene_shared_text_layout_engine.dart';
import 'package:refusion_app/features/editor/domain/services/scene_shared_text_layout_models.dart';

void main() {
  const engine = SceneSharedTextLayoutEngine();

  test('shrinkToFit lowers font size until bounded text fits', () {
    const request = SceneSharedTextLayoutRequest(
      text: 'generate new offer for my business',
      frameWidth: 260,
      frameHeight: 44,
      fontSize: 34,
      lineHeight: 1.1,
      letterSpacing: 0,
      maxLines: 1,
      fitPolicy: 'shrinkToFit',
      minFontSize: 12,
    );
    final result = engine.layout(request);
    expect(result.fits, isTrue);
    expect(result.effectiveFontSize, lessThan(request.fontSize));
  });

  test('none fitPolicy fails when overflow remains', () {
    const request = SceneSharedTextLayoutRequest(
      text: 'generate new offer for my business',
      frameWidth: 260,
      frameHeight: 44,
      fontSize: 34,
      lineHeight: 1.1,
      letterSpacing: 0,
      maxLines: 1,
      fitPolicy: 'none',
    );
    final result = engine.layout(request);
    expect(result.fits, isFalse);
    expect(result.overflowPx, greaterThan(1));
  });

  test('ellipsisAfterMaxLines is accepted for bounded multi-line fallback', () {
    const request = SceneSharedTextLayoutRequest(
      text: 'Very long static text body for bounded layout checks',
      frameWidth: 220,
      frameHeight: 54,
      fontSize: 22,
      lineHeight: 1.2,
      letterSpacing: 0,
      maxLines: 2,
      fitPolicy: 'ellipsisAfterMaxLines',
    );
    final result = engine.layout(request);
    expect(result.fits, isTrue);
    expect(result.normalizedFitPolicy, 'ellipsisaftermaxlines');
  });
}
