import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:navi_app/services/mapbox_config.dart';

/// Describes the bounds of the Nairobi offline region.
class OfflineRegionBounds {
  final double minLongitude;
  final double minLatitude;
  final double maxLongitude;
  final double maxLatitude;

  const OfflineRegionBounds({
    required this.minLongitude,
    required this.minLatitude,
    required this.maxLongitude,
    required this.maxLatitude,
  });

  /// Builds a closed GeoJSON polygon covering the bounds.
  Map<String?, Object?> toPolygonGeometry() {
    return <String?, Object?>{
      'type': 'Polygon',
      'coordinates': [
        [
          [minLongitude, minLatitude],
          [maxLongitude, minLatitude],
          [maxLongitude, maxLatitude],
          [minLongitude, maxLatitude],
          [minLongitude, minLatitude],
        ],
      ],
    };
  }
}

/// Result of a (partial) offline download.
class OfflineRegionStatus {
  final bool stylePackDownloaded;
  final bool tileRegionDownloaded;

  const OfflineRegionStatus({
    required this.stylePackDownloaded,
    required this.tileRegionDownloaded,
  });

  bool get isDownloaded => stylePackDownloaded && tileRegionDownloaded;
}

/// Manages the real Mapbox offline map pipeline for the Nairobi region.
///
/// Uses [OfflineManager] for style packs and [TileStore] for tile regions so
/// tiles are actually stored on device and can be rendered without a network
/// connection (airplane mode render).
class OfflineMapService {
  static const String regionId = 'nairobi';

  static const OfflineRegionBounds regionBounds = OfflineRegionBounds(
    minLongitude: 36.65,
    minLatitude: -1.45,
    maxLongitude: 37.10,
    maxLatitude: -1.05,
  );

  static const int minZoom = 10;
  static const int maxZoom = 16;

  static const Map<String, Object> _metadata = {
    'region': regionId,
    'name': 'Nairobi Offline Map',
  };

  OfflineManager? _offlineManager;
  TileStore? _tileStore;

  /// Lazily creates the shared [OfflineManager] and [TileStore] instances.
  Future<void> init() async {
    if (_offlineManager == null) {
      MapboxOptions.setAccessToken(MapboxConfig.accessToken);
      _offlineManager = await OfflineManager.create();
    }
    _tileStore ??= await TileStore.createDefault();
  }

  /// The style pack and tile region load options for the Nairobi region.
  StylePackLoadOptions get _stylePackOptions => StylePackLoadOptions(
        glyphsRasterizationMode:
            GlyphsRasterizationMode.IDEOGRAPHS_RASTERIZED_LOCALLY,
        metadata: Map<String?, Object?>.from(_metadata),
        acceptExpired: true,
      );

  TileRegionLoadOptions get _tileRegionOptions => TileRegionLoadOptions(
        geometry: regionBounds.toPolygonGeometry(),
        descriptorsOptions: [
          TilesetDescriptorOptions(
            styleURI: MapboxConfig.styleForTheme(false),
            minZoom: minZoom,
            maxZoom: maxZoom,
          ),
          TilesetDescriptorOptions(
            styleURI: MapboxConfig.styleForTheme(true),
            minZoom: minZoom,
            maxZoom: maxZoom,
          ),
        ],
        metadata: _metadata,
        acceptExpired: true,
        networkRestriction: NetworkRestriction.NONE,
      );

  /// Returns the current download status for the Nairobi region.
  Future<OfflineRegionStatus> getStatus() async {
    await init();
    var stylePackDownloaded = false;
    var tileRegionDownloaded = false;
    final manager = _offlineManager!;
    final tileStore = _tileStore!;

    try {
      final pack = await manager.stylePack(MapboxConfig.styleForTheme(false));
      stylePackDownloaded = pack.requiredResourceCount > 0 &&
          pack.completedResourceCount >= pack.requiredResourceCount;
    } catch (_) {
      stylePackDownloaded = false;
    }

    try {
      final region = await tileStore.tileRegion(regionId);
      tileRegionDownloaded = region.completedResourceCount > 0;
    } catch (_) {
      tileRegionDownloaded = false;
    }

    return OfflineRegionStatus(
      stylePackDownloaded: stylePackDownloaded,
      tileRegionDownloaded: tileRegionDownloaded,
    );
  }

  /// Estimates the on-disk storage size (in bytes) for the Nairobi region.
  Future<int> estimateRegionSize() async {
    await init();
    final estimate = await _tileStore!.estimateTileRegion(
      regionId,
      _tileRegionOptions,
      TileRegionEstimateOptions(
        errorMargin: 0.1,
        preciseEstimationTimeout: 5,
        timeout: 30,
      ),
      null,
    );
    return estimate.storageSize;
  }

  /// Downloads the Nairobi region (style packs + tile region), reporting
  /// combined progress in the range 0.0..1.0.
  Future<void> downloadRegion({
    void Function(double progress)? onProgress,
    void Function()? onStylePackComplete,
    VoidCallback? onComplete,
    void Function(Object error)? onError,
  }) async {
    await init();
    final manager = _offlineManager!;
    final tileStore = _tileStore!;
    final styleUri = MapboxConfig.styleForTheme(false);

    final stylePackKey = 'style-pack';
    final tileRegionKey = 'tile-region';
    final progressByPhase = <String, double>{
      stylePackKey: 0.0,
      tileRegionKey: 0.0,
    };

    void reportProgress() {
      final styleProgress = progressByPhase[stylePackKey] ?? 0.0;
      final tileProgress = progressByPhase[tileRegionKey] ?? 0.0;
      // Style pack is the smaller part of the download (~10% of data).
      onProgress?.call((styleProgress * 0.4) + (tileProgress * 0.6));
    }

    try {
      await manager.loadStylePack(styleUri, _stylePackOptions, (progress) {
        progressByPhase[stylePackKey] =
            progress.requiredResourceCount == 0
                ? 1.0
                : progress.completedResourceCount /
                    progress.requiredResourceCount;
        reportProgress();
      });
      progressByPhase[stylePackKey] = 1.0;
      onStylePackComplete?.call();
      reportProgress();

      await tileStore.loadTileRegion(
          regionId, _tileRegionOptions, (progress) {
        progressByPhase[tileRegionKey] =
            progress.requiredResourceCount == 0
                ? 1.0
                : progress.completedResourceCount /
                    progress.requiredResourceCount;
        reportProgress();
      });
      progressByPhase[tileRegionKey] = 1.0;
      reportProgress();
      onComplete?.call();
    } catch (e, s) {
      debugPrint('[OfflineMap] download failed: $e\n$s');
      onError?.call(e);
    }
  }

  /// Removes the downloaded Nairobi style pack and tile region.
  Future<void> deleteRegion() async {
    await init();
    try {
      await _offlineManager?.removeStylePack(MapboxConfig.styleForTheme(false));
    } catch (_) {}
    try {
      await _offlineManager?.removeStylePack(MapboxConfig.styleForTheme(true));
    } catch (_) {}
    try {
      await _tileStore?.removeRegion(regionId);
    } catch (_) {}
  }
}