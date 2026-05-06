import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/edge_fill_directive_compiler.dart';

void main() {
  const compiler = EdgeFillDirectiveCompiler();

  test('disables edge fill when policy is disabled', () {
    final directive = compiler.compile(
      policy: const MasterEdgeFillPolicy(enabled: false),
      transform: const LiveScrubSurfaceTransform(),
      quality: EdgeFillDirectiveQuality.liveScrub,
      canvasWidth: 1080,
      canvasHeight: 1920,
      sourceWidth: 1080,
      sourceHeight: 1920,
      requiresFullCanvasCoverage: true,
    );

    expect(directive.enabled, isFalse);
    expect(directive.fallbackReason, 'edge_fill_disabled');
  });

  test('disables edge fill when source dimensions are missing', () {
    final directive = compiler.compile(
      policy: const MasterEdgeFillPolicy(
        enabled: true,
        amount: 1.0,
      ),
      transform: const LiveScrubSurfaceTransform(),
      quality: EdgeFillDirectiveQuality.preview,
      canvasWidth: 1080,
      canvasHeight: 1920,
      sourceWidth: null,
      sourceHeight: null,
      requiresFullCanvasCoverage: true,
    );

    expect(directive.enabled, isFalse);
    expect(directive.fallbackReason, 'edge_fill_source_dimensions_missing');
  });

  test('enables edge fill when transform creates blank bounds', () {
    final directive = compiler.compile(
      policy: const MasterEdgeFillPolicy(
        enabled: true,
        amount: 1.0,
        mode: MasterEdgeFillMode.reflect,
      ),
      transform: const LiveScrubSurfaceTransform(
        scaleX: 0.8,
        scaleY: 0.8,
        rotationRadians: math.pi / 4,
      ),
      quality: EdgeFillDirectiveQuality.playback,
      canvasWidth: 1080,
      canvasHeight: 1920,
      sourceWidth: 1080,
      sourceHeight: 1920,
      requiresFullCanvasCoverage: true,
    );

    expect(directive.enabled, isTrue);
    expect(directive.overscanScale, greaterThan(1.0));
    expect(directive.sourceRectLeft, closeTo(0.0, 1e-6));
    expect(directive.sourceRectTop, closeTo(0.0, 1e-6));
    expect(directive.sourceRectRight, closeTo(1.0, 1e-6));
    expect(directive.sourceRectBottom, closeTo(1.0, 1e-6));
    expect(directive.transformMatrix3x3, hasLength(9));
    expect(directive.inverseTransformMatrix3x3, hasLength(9));
    expect(directive.fallbackReason, isNull);
  });

  test('keeps motion tile active for rotated full-canvas content', () {
    final directive = compiler.compile(
      policy: const MasterEdgeFillPolicy(
        enabled: true,
        amount: 1.0,
        mode: MasterEdgeFillMode.reflect,
      ),
      transform: const LiveScrubSurfaceTransform(
        rotationRadians: math.pi / 4,
      ),
      quality: EdgeFillDirectiveQuality.liveScrub,
      canvasWidth: 1080,
      canvasHeight: 1920,
      sourceWidth: 1080,
      sourceHeight: 1920,
      requiresFullCanvasCoverage: true,
    );

    expect(directive.enabled, isTrue);
    expect(directive.mode, MasterEdgeFillMode.reflect.name);
    expect(directive.overscanScale, greaterThan(1.0001));
    expect(directive.sourceRectLeft, closeTo(0.0, 1e-6));
    expect(directive.sourceRectTop, closeTo(0.0, 1e-6));
    expect(directive.sourceRectRight, closeTo(1.0, 1e-6));
    expect(directive.sourceRectBottom, closeTo(1.0, 1e-6));
    expect(directive.fallbackReason, isNull);
  });

  test('rotation transform keeps canvas center fixed', () {
    final directive = compiler.compile(
      policy: const MasterEdgeFillPolicy(
        enabled: true,
        amount: 1.0,
        mode: MasterEdgeFillMode.reflect,
      ),
      transform: const LiveScrubSurfaceTransform(
        rotationRadians: math.pi / 3,
      ),
      quality: EdgeFillDirectiveQuality.playback,
      canvasWidth: 1080,
      canvasHeight: 1920,
      sourceWidth: 1080,
      sourceHeight: 1920,
      requiresFullCanvasCoverage: true,
    );

    final matrix = directive.transformMatrix3x3;
    final centerX = directive.canvasWidth / 2.0;
    final centerY = directive.canvasHeight / 2.0;
    final transformedCenterX =
        (matrix[0] * centerX) + (matrix[1] * centerY) + matrix[2];
    final transformedCenterY =
        (matrix[3] * centerX) + (matrix[4] * centerY) + matrix[5];

    expect(transformedCenterX, closeTo(centerX, 1e-6));
    expect(transformedCenterY, closeTo(centerY, 1e-6));
  });

  test('keeps motion tile active at quarter turns', () {
    final directive = compiler.compile(
      policy: const MasterEdgeFillPolicy(
        enabled: true,
        amount: 1.0,
        mode: MasterEdgeFillMode.reflect,
      ),
      transform: const LiveScrubSurfaceTransform(
        rotationRadians: math.pi / 2,
      ),
      quality: EdgeFillDirectiveQuality.playback,
      canvasWidth: 1080,
      canvasHeight: 1920,
      sourceWidth: 1080,
      sourceHeight: 1920,
      requiresFullCanvasCoverage: true,
    );

    expect(directive.enabled, isTrue);
    expect(directive.overscanScale, greaterThan(1.0001));
    expect(directive.fallbackReason, isNull);
  });

  test('disables edge fill when content already covers canvas', () {
    final directive = compiler.compile(
      policy: const MasterEdgeFillPolicy(
        enabled: true,
        amount: 1.0,
      ),
      transform: const LiveScrubSurfaceTransform(
        scaleX: 1.4,
        scaleY: 1.4,
      ),
      quality: EdgeFillDirectiveQuality.playback,
      canvasWidth: 1080,
      canvasHeight: 1920,
      sourceWidth: 1080,
      sourceHeight: 1920,
      requiresFullCanvasCoverage: true,
    );

    expect(directive.enabled, isFalse);
    expect(directive.fallbackReason, 'edge_fill_bounds_already_covered');
  });

  test('explicit overscan keeps motion tile active and bounded', () {
    final directive = compiler.compile(
      policy: const MasterEdgeFillPolicy(
        enabled: true,
        amount: 1.0,
        mode: MasterEdgeFillMode.reflect,
        overscanScale: 1.4,
      ),
      transform: const LiveScrubSurfaceTransform(),
      quality: EdgeFillDirectiveQuality.preview,
      canvasWidth: 1080,
      canvasHeight: 1920,
      sourceWidth: 1080,
      sourceHeight: 1920,
      requiresFullCanvasCoverage: true,
    );

    expect(directive.enabled, isTrue);
    expect(directive.overscanScale, greaterThanOrEqualTo(1.4));
    expect(directive.sourceRectLeft, inInclusiveRange(0.0, 1.0));
    expect(directive.sourceRectTop, inInclusiveRange(0.0, 1.0));
    expect(directive.sourceRectRight, inInclusiveRange(0.0, 1.0));
    expect(directive.sourceRectBottom, inInclusiveRange(0.0, 1.0));
    expect(directive.fallbackReason, isNull);
  });
}
