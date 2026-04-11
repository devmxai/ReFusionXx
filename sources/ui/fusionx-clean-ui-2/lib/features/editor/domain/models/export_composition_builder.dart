import '../../presentation/models/timeline_time.dart';
import 'export_authored_visual_surface_models.dart';
import 'export_composition_models.dart';
import 'professional_motion_text_raster_models.dart';

class ExportCompositionBuilder {
  const ExportCompositionBuilder();

  ExportComposition build(ExportCompositionBuildInput input) {
    final assetsById = <String, ExportAssetDescriptor>{
      for (final asset in input.assets) asset.assetId: asset,
    };
    final issues = <ExportCompositionIssue>[];
    final tracks = <ExportTrackDescriptor>[];

    for (final trackSeed in input.timelineTracks) {
      final clips = <ExportClipDescriptor>[];
      for (final clipSeed in trackSeed.clips) {
        if (clipSeed.isPlaceholder) {
          issues.add(
            ExportCompositionIssue(
              code: ExportCompositionIssueCode.placeholderClip,
              severity: ExportCompositionIssueSeverity.warning,
              message:
                  'Placeholder clip `${clipSeed.clipId}` was excluded from export composition.',
              trackKind: trackSeed.kind,
              clipId: clipSeed.clipId,
              assetId: clipSeed.assetId,
            ),
          );
          continue;
        }
        final assetId = clipSeed.assetId;
        if (assetId == null || assetId.isEmpty) {
          issues.add(
            ExportCompositionIssue(
              code: ExportCompositionIssueCode.missingAsset,
              severity: ExportCompositionIssueSeverity.error,
              message:
                  'Clip `${clipSeed.clipId}` is missing an export asset id.',
              trackKind: trackSeed.kind,
              clipId: clipSeed.clipId,
            ),
          );
          continue;
        }
        final asset = assetsById[assetId];
        if (asset == null) {
          issues.add(
            ExportCompositionIssue(
              code: ExportCompositionIssueCode.missingAsset,
              severity: ExportCompositionIssueSeverity.error,
              message:
                  'Clip `${clipSeed.clipId}` points to missing asset `$assetId`.',
              trackKind: trackSeed.kind,
              clipId: clipSeed.clipId,
              assetId: assetId,
            ),
          );
          continue;
        }
        if (!asset.hasSourceUri) {
          issues.add(
            ExportCompositionIssue(
              code: ExportCompositionIssueCode.missingSourceUri,
              severity: ExportCompositionIssueSeverity.error,
              message:
                  'Asset `$assetId` does not have a usable source uri for export.',
              trackKind: trackSeed.kind,
              clipId: clipSeed.clipId,
              assetId: assetId,
            ),
          );
          continue;
        }
        final timelineRange = TimelineTimeRange(
          start: clipSeed.timelineStartTime,
          endExclusive:
              clipSeed.timelineStartTime + clipSeed.timelineDurationTime,
        );
        final sourceRange = TimelineTimeRange(
          start: clipSeed.sourceStartTime,
          endExclusive: clipSeed.sourceStartTime + clipSeed.sourceDurationTime,
        );
        clips.add(
          ExportClipDescriptor(
            clipId: clipSeed.clipId,
            trackKind: trackSeed.kind,
            assetId: assetId,
            timelineRange: timelineRange,
            sourceRange: sourceRange,
            playbackRate: clipSeed.playbackRate,
            speedMode: clipSeed.speedMode,
            splitGroupId: clipSeed.splitGroupId,
            label: clipSeed.label ?? asset.label,
          ),
        );
      }
      tracks.add(
        ExportTrackDescriptor(
          kind: trackSeed.kind,
          clips: clips,
        ),
      );
    }

    final canonicalEffectsGraph =
        buildCanonicalEffectsGraphForExportComposition(
      format: input.projectFormat,
      tracks: tracks,
      motionComposition: input.motionComposition,
      motionTextProgram: input.motionTextProgram,
      motionTextRenderTrack: input.motionTextRenderTrack,
    );
    final motionTextRasterContract =
        buildMotionTextRasterContractForExportComposition(
      motionComposition: input.motionComposition,
      motionTextProgram: input.motionTextProgram,
      motionTextRenderTrack: input.motionTextRenderTrack,
    );
    final motionTextRasterProgram = buildMotionTextRasterExportProgram(
      contract: motionTextRasterContract,
      motionTextProgram: input.motionTextProgram,
    );
    final authoredVisualSurfaceProgram =
        buildExportAuthoredVisualSurfaceProgram(
      input.motionComposition,
    );

    return ExportComposition(
      contractVersion: input.contractVersion,
      projectId: input.projectId,
      format: input.projectFormat,
      assets: input.assets,
      tracks: tracks,
      canonicalEffectsGraph: canonicalEffectsGraph,
      motionTextRasterContract: motionTextRasterContract,
      motionTextRasterProgram: motionTextRasterProgram,
      authoredVisualSurfaceProgram: authoredVisualSurfaceProgram,
      motionComposition: input.motionComposition,
      motionTextProgram: input.motionTextProgram,
      motionTextRenderTrack: input.motionTextRenderTrack,
      issues: issues,
    );
  }
}
