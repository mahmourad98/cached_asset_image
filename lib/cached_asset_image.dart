//ignore_for_file: unnecessary_library_name

/// Main library for the cached_asset_image package.
///
/// This library provides widgets and managers for caching and displaying
/// both bitmap and vector (SVG) assets with persistent disk-based caching.
///
/// ## Features
/// - **Persistent Disk Caching**: Uses flutter_cache_manager for reliable storage
/// - **Automatic Cache Management**: Configurable retention and size limits
/// - **Survives App Restarts**: Cached assets persist across sessions
/// - Support for both bitmap and vector (SVG) assets
/// - Smooth fade-in/fade-out transitions
/// - Placeholder and error widgets
/// - Color tinting and blend modes for SVG assets
/// - Custom cache manager support
/// - Cache key override for advanced control
/// - Accessibility support with semantics control
///
/// ## Usage
///
/// ### Basic Usage - Bitmap Assets:
/// ```dart
/// CachedAssetBitmapImage(
///   assetPath: 'assets/images/logo.png',
///   width: 200,
///   height: 200,
///   placeholder: CircularProgressIndicator(),
///   errorWidget: Icon(Icons.error),
/// )
/// ```
///
/// ### Basic Usage - Vector (SVG) Assets:
/// ```dart
/// CachedAssetVectorImage(
///   assetPath: 'assets/icons/icon.svg',
///   width: 100,
///   height: 100,
///   color: Colors.blue,
///   placeholder: CircularProgressIndicator(),
///   semanticsLabel: 'App logo', // For accessibility
/// )
/// ```
///
/// ### Advanced Usage - Custom Cache Manager:
/// ```dart
/// // Use the default singleton cache managers
/// final bitmapCache = BitmapAssetCacheManager();
/// final vectorCache = VectorAssetCacheManager();
///
/// // Widgets accept any CacheManager (optimized for specific types)
/// CachedAssetBitmapImage(
///   assetPath: 'assets/images/logo.png',
///   cacheManager: bitmapCache, // BitmapAssetCacheManager for optimized performance
/// )
///
/// CachedAssetVectorImage(
///   assetPath: 'assets/icons/icon.svg',
///   cacheManager: vectorCache, // VectorAssetCacheManager for optimized performance
/// )
///
/// // Or use any other CacheManager (with generic fallback)
/// final customCache = CacheManager(Config('myCustomCache'));
/// CachedAssetBitmapImage(
///   assetPath: 'assets/images/logo.png',
///   cacheManager: customCache, // Works with any CacheManager
/// )
/// ```
///
/// ### Cache Management:
/// ```dart
/// // Get cache manager instance
/// final bitmapCache = BitmapAssetCacheManager();
/// final vectorCache = VectorAssetCacheManager();
///
/// // Clear specific asset from cache
/// await bitmapCache.removeFromCache('assets/images/logo.png');
///
/// // Clear entire cache
/// await bitmapCache.clearCache();
/// await vectorCache.clearCache();
///
/// // Get cache info
/// final info = await bitmapCache.getCacheInfo();
/// print('Cache size: ${info['cacheSize']}');
/// ```
///
/// ## Cache Managers
///
/// Both cache managers extend `CacheManager` directly, providing full access to
/// flutter_cache_manager functionality while adding asset-specific optimizations.
///
/// **Widget Flexibility**: All widgets accept `CacheManager?` parameter, allowing:
/// - **Optimized Performance**: Use matching cache manager for best performance
/// - **Generic Compatibility**: Use any CacheManager with automatic fallback  
/// - **Custom Implementations**: Pass your own CacheManager instances
///
/// - **`BitmapAssetCacheManager`**: Singleton extending `CacheManager with ImageCacheManager`
///   - Persistent disk caching with 7-day retention
///   - Optimized `get(String)` method for bitmap images
///   - Default: 200 cache objects
///
/// - **`VectorAssetCacheManager`**: Singleton extending `CacheManager`
///   - Persistent disk caching with 7-day retention  
///   - Optimized `getSvg(...)` method with parameterized caching
///   - Default: 100 cache objects
///   - Handles color filters, dimensions, and SVG-specific optimizations
library cached_asset_image;

// Export all public APIs
export 'asset_cache_manager.dart' show
  // Cache Managers
  BitmapAssetCacheManager,
  VectorAssetCacheManager;

export 'cached_asset_vector_image.dart' show CachedAssetVectorImage;
export 'cached_asset_bitmap_image.dart' show CachedAssetBitmapImage;

