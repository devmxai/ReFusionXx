import 'scene_brand_asset_pipeline.dart';

class SceneBrandAssetCacheEntry {
  const SceneBrandAssetCacheEntry({
    required this.key,
    required this.resolution,
  });

  final String key;
  final SceneBrandAssetPipelineResolution resolution;
}

class SceneBrandAssetCache {
  SceneBrandAssetCache();

  final Map<String, SceneBrandAssetCacheEntry> _entries =
      <String, SceneBrandAssetCacheEntry>{};

  SceneBrandAssetPipelineResolution? read(String key) {
    return _entries[key]?.resolution;
  }

  void write(String key, SceneBrandAssetPipelineResolution resolution) {
    _entries[key] = SceneBrandAssetCacheEntry(
      key: key,
      resolution: resolution,
    );
  }

  void clear() => _entries.clear();
}
