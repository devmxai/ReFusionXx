import 'package:flutter/foundation.dart';

enum ExportResolutionPreset {
  draft720p('720p'),
  fullHd1080p('1080p'),
  quadHd1440p('1440p'),
  ultraHd2160p('2160p'),
  originalCanvas('Original Canvas'),
  sourceMatch('Source Match');

  const ExportResolutionPreset(this.label);

  final String label;
}

enum ExportFrameRatePreset {
  fps24(24),
  fps25(25),
  fps30(30),
  fps50(50),
  fps60(60),
  fps90(90),
  fps120(120);

  const ExportFrameRatePreset(this.framesPerSecond);

  final int framesPerSecond;

  static ExportFrameRatePreset closestTo(double framesPerSecond) {
    return ExportFrameRatePreset.values.reduce(
      (currentBest, candidate) {
        final currentDelta =
            (currentBest.framesPerSecond - framesPerSecond).abs();
        final candidateDelta =
            (candidate.framesPerSecond - framesPerSecond).abs();
        return candidateDelta < currentDelta ? candidate : currentBest;
      },
    );
  }
}

enum ExportVideoCodecPreset {
  automatic('Auto'),
  h264Avc('H.264 / AVC'),
  h265Hevc('H.265 / HEVC');

  const ExportVideoCodecPreset(this.label);

  final String label;
}

enum ExportBitrateMode {
  auto('Auto'),
  qualityPriority('Quality'),
  sizePriority('Size'),
  manual('Manual');

  const ExportBitrateMode(this.label);

  final String label;
}

enum ExportAudioBitratePreset {
  kbps128(128000, '128 kbps'),
  kbps192(192000, '192 kbps'),
  kbps256(256000, '256 kbps'),
  kbps320(320000, '320 kbps');

  const ExportAudioBitratePreset(this.bitsPerSecond, this.label);

  final int bitsPerSecond;
  final String label;
}

@immutable
class ExportOutputProfile {
  const ExportOutputProfile({
    required this.resolutionPreset,
    required this.frameRate,
    this.videoCodec = ExportVideoCodecPreset.automatic,
    this.bitrateMode = ExportBitrateMode.auto,
    this.audioBitrate = ExportAudioBitratePreset.kbps256,
    this.manualVideoBitrate,
  });

  final ExportResolutionPreset resolutionPreset;
  final ExportFrameRatePreset frameRate;
  final ExportVideoCodecPreset videoCodec;
  final ExportBitrateMode bitrateMode;
  final ExportAudioBitratePreset audioBitrate;
  final int? manualVideoBitrate;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'resolutionPreset': resolutionPreset.name,
        'frameRate': frameRate.framesPerSecond,
        'videoCodec': videoCodec.name,
        'bitrateMode': bitrateMode.name,
        'audioBitrate': audioBitrate.bitsPerSecond,
        'manualVideoBitrate': manualVideoBitrate,
      };
}
