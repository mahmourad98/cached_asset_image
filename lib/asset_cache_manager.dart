/// Asset cache management using flutter_cache_manager.
///
/// This library provides cache managers that use flutter_cache_manager for
/// persistent disk-based caching with automatic cleanup and efficient memory management.
library;

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart' as svg;

/// Cache manager for bitmap assets extending CacheManager directly.
/// 
/// This implementation provides persistent disk-based caching with automatic
/// cleanup and efficient memory management. Cached assets survive app restarts.
class BitmapAssetCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'bitmapAssetCache';
  static BitmapAssetCacheManager? _instance;

  factory BitmapAssetCacheManager() {
    return _instance ??= BitmapAssetCacheManager._();
  }

  BitmapAssetCacheManager._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 200,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ));

  /// Get an image from cache or load it from assets
  Future<ui.Image> get(String assetPath) async {
    try {
      // Try to get from file cache first
      final file = await getSingleFile(
        'asset://$assetPath',
        key: assetPath,
      );
      
      final bytes = await file.readAsBytes();
      return await _decodeImageFromBytes(bytes);
    } catch (e) {
      // If not in cache, load from assets and cache it
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Cache the bytes
      await putFile(
        'asset://$assetPath',
        bytes,
        key: assetPath,
      );
      
      return await _decodeImageFromBytes(bytes);
    }
  }

  /// Decode image from bytes
  Future<ui.Image> _decodeImageFromBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Remove specific asset from cache
  Future<void> removeFromCache(String assetPath) async {
    await removeFile(assetPath);
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    await emptyCache();
  }

  /// Get cache info
  Future<Map<String, dynamic>> getCacheInfo() async {
    return {
      'cacheSize': await _getCacheSize(),
    };
  }

  Future<int> _getCacheSize() async {
    try {
      // Get all cached files and sum their sizes
      // Note: This is a simplified implementation
      // flutter_cache_manager doesn't expose direct cache size info
      return 0; // Placeholder - would need custom implementation
    } catch (e) {
      // Ignore errors getting cache size
    }
    return 0;
  }
}

/// Cache manager for vector (SVG) assets extending CacheManager directly.
/// 
/// This implementation provides persistent disk-based caching for SVG assets
/// with parameterized caching based on rendering parameters. Cached assets survive app restarts.
class VectorAssetCacheManager extends CacheManager {
  static const key = 'vectorAssetCache';
  static VectorAssetCacheManager? _instance;

  factory VectorAssetCacheManager() {
    return _instance ??= VectorAssetCacheManager._();
  }

  VectorAssetCacheManager._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 100,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ));

  /// Get an SVG PictureInfo from cache or load it from assets
  Future<svg.PictureInfo> getSvg(
    String assetPath, {
    ui.ColorFilter? colorFilter,
    double? width,
    double? height,
  }) async {
    final key = _generateCacheKey(assetPath, colorFilter, width, height);
    
    try {
      // Try to get from file cache first
      final file = await getSingleFile(
        'svg-asset://$assetPath',
        key: key,
      );
      
      final svgString = await file.readAsString();
      return await _parseSvgString(svgString);
    } catch (e) {
      // If not in cache, load from assets and cache it
      final String svgString = await rootBundle.loadString(assetPath);
      
      // Cache the SVG string
      await putFile(
        'svg-asset://$assetPath',
        Uint8List.fromList(svgString.codeUnits),
        key: key,
      );
      
      return await _parseSvgString(svgString);
    }
  }

  /// Generate cache key based on parameters
  String _generateCacheKey(
    String assetPath,
    ui.ColorFilter? colorFilter,
    double? width,
    double? height,
  ) {
    final buffer = StringBuffer(assetPath);
    if (colorFilter != null) {
      buffer.write('_cf${colorFilter.hashCode}');
    }
    if (width != null) {
      buffer.write('_w$width');
    }
    if (height != null) {
      buffer.write('_h$height');
    }
    return buffer.toString();
  }

  /// Parse SVG string into PictureInfo
  Future<svg.PictureInfo> _parseSvgString(String svgString) async {
    return await svg.vg.loadPicture(
      svg.SvgStringLoader(svgString),
      null,
    );
  }

  /// Remove all variations of an asset path
  Future<void> removeAssetFromCache(String assetPath) async {
    // Note: flutter_cache_manager doesn't provide easy way to remove by prefix
    // This would require custom implementation or clearing entire cache
    await emptyCache();
  }

  /// Remove specific cache entry
  Future<void> removeFromCache(String key) async {
    await removeFile(key);
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    await emptyCache();
  }

  /// Get cache info
  Future<Map<String, dynamic>> getCacheInfo() async {
    return {
      'cacheSize': await _getCacheSize(),
    };
  }

  Future<int> _getCacheSize() async {
    try {
      // Get all cached files and sum their sizes
      // Note: This is a simplified implementation
      // flutter_cache_manager doesn't expose direct cache size info
      return 0; // Placeholder - would need custom implementation
    } catch (e) {
      // Ignore errors getting cache size
    }
    return 0;
  }
}

