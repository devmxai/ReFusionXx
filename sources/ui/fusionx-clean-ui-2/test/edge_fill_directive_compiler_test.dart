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
      policy: const MasterEdgeFillPolicy(),
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
    expect(directive.fallbackReason, isNull);
  });

  test('disables edge fill when content already covers canvas', () {
    final directive = compiler.compile(
      policy: const MasterEdgeFillPolicy(),
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
}
