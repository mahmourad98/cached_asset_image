/// Widget implementation for cached Bitmap asset images.
///
/// This library provides the [CachedAssetBitmapImage] widget for displaying
/// Bitmap assets with caching support and smooth fade transitions.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'asset_cache_manager.dart';

class CachedAssetBitmapImage extends StatefulWidget {
  const CachedAssetBitmapImage({
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.none,
    this.alignment = Alignment.center,
    this.color,
    this.colorBlendMode,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.fadeOutDuration = const Duration(milliseconds: 300),
    this.fadeInCurve = Curves.easeIn,
    this.fadeOutCurve = Curves.easeOut,
    this.excludeFromSemantics = false,
    this.cacheKey,
    this.cacheManager,
    super.key,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Color? color;
  final BlendMode? colorBlendMode;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final Curve fadeInCurve;
  final Curve fadeOutCurve;

  /// Whether to exclude this widget from the semantics tree.
  final bool excludeFromSemantics;

  /// Optional cache key override. If not provided, [assetPath] will be used.
  final String? cacheKey;

  /// Optional cache manager instance. If not provided, the default singleton will be used.
  /// Can be any CacheManager - if it's a BitmapAssetCacheManager, it will use the optimized get() method.
  final CacheManager? cacheManager;

  @override
  State<CachedAssetBitmapImage> createState() => _CachedAssetBitmapImageState();
}

class _CachedAssetBitmapImageState extends State<CachedAssetBitmapImage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late CacheManager _cacheManager;

  ui.Image? _image;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _cacheManager = widget.cacheManager ?? BitmapAssetCacheManager();
    _animationController = AnimationController(
      duration: widget.fadeInDuration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: widget.fadeInCurve,
    );
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedAssetBitmapImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheManager != widget.cacheManager) {
      _cacheManager = widget.cacheManager ?? BitmapAssetCacheManager();
    }
    if (oldWidget.assetPath != widget.assetPath || oldWidget.cacheKey != widget.cacheKey) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Use cacheKey if provided, otherwise use assetPath
      final key = widget.cacheKey ?? widget.assetPath;
      
      // If it's a BitmapAssetCacheManager, use the optimized get() method
      final ui.Image image;
      if (_cacheManager is BitmapAssetCacheManager) {
        image = await (_cacheManager as BitmapAssetCacheManager).get(key);
      } else {
        // Use generic CacheManager approach
        image = await _loadImageFromGenericCache(key);
      }
      
      if (mounted) {
        setState(() {
          _image = image;
          _isLoading = false;
        });
        await _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  /// Load image using generic CacheManager (fallback for non-BitmapAssetCacheManager)
  Future<ui.Image> _loadImageFromGenericCache(String key) async {
    try {
      // Try to get from file cache first
      final file = await _cacheManager.getSingleFile(
        'asset://${widget.assetPath}',
        key: key,
      );
      
      final bytes = await file.readAsBytes();
      return await _decodeImageFromBytes(bytes);
    } catch (e) {
      // If not in cache, load from assets and cache it
      final ByteData data = await rootBundle.load(widget.assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Cache the bytes
      await _cacheManager.putFile(
        'asset://${widget.assetPath}',
        bytes,
        key: key,
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && widget.errorWidget != null) {
      return widget.errorWidget!;
    }

    if (_isLoading && widget.placeholder != null) {
      return widget.placeholder!;
    }

    if (_image == null) {
      return const SizedBox.shrink();
    }

    Widget imageWidget = AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: CustomPaint(
            size: Size(
              widget.width ?? _image!.width.toDouble(),
              widget.height ?? _image!.height.toDouble(),
            ),
            painter: _AssetImagePainter(
              image: _image!,
              fit: widget.fit,
              alignment: widget.alignment,
              color: widget.color,
              colorBlendMode: widget.colorBlendMode,
            ),
          ),
        );
      },
    );

    if (widget.excludeFromSemantics) {
      imageWidget = ExcludeSemantics(child: imageWidget);
    }

    return imageWidget;
  }
}

class _AssetImagePainter extends CustomPainter {
  _AssetImagePainter({
    required this.image,
    this.fit = BoxFit.none,
    this.alignment = Alignment.center,
    this.color,
    this.colorBlendMode,
  });

  final ui.Image image;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Color? color;
  final BlendMode? colorBlendMode;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..isAntiAlias = true;

    if (color != null) {
      paint.colorFilter = ColorFilter.mode(color!, colorBlendMode ?? BlendMode.srcIn);
    }

    final inputSize = Size(image.width.toDouble(), image.height.toDouble());
    final sizes = applyBoxFit(fit, inputSize, size);
    final FittedSizes fittedSizes = FittedSizes(sizes.source, sizes.destination);

    final Rect inputRect = alignment.resolve(null).inscribe(
          fittedSizes.source,
          Offset.zero & inputSize,
        );
    final Rect outputRect = alignment.resolve(null).inscribe(
          fittedSizes.destination,
          Offset.zero & size,
        );

    canvas.drawImageRect(image, inputRect, outputRect, paint);
  }

  @override
  bool shouldRepaint(_AssetImagePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.fit != fit ||
        oldDelegate.alignment != alignment ||
        oldDelegate.color != color ||
        oldDelegate.colorBlendMode != colorBlendMode;
  }
}
