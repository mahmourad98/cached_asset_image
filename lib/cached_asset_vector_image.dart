/// Widget implementation for cached SVG asset images.
///
/// This library provides the [CachedAssetVectorImage] widget for displaying
/// SVG assets with caching support and smooth fade transitions.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart' as svg;

import 'asset_cache_manager.dart';

class CachedAssetVectorImage extends StatefulWidget {
  const CachedAssetVectorImage({
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.none,
    this.alignment = Alignment.center,
    this.color,
    this.colorBlendMode = BlendMode.srcIn,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.fadeOutDuration = const Duration(milliseconds: 300),
    this.fadeInCurve = Curves.easeIn,
    this.fadeOutCurve = Curves.easeOut,
    this.matchTextDirection = false,
    this.allowDrawingOutsideViewBox = false,
    this.semanticsLabel,
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
  final BlendMode colorBlendMode;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final Curve fadeInCurve;
  final Curve fadeOutCurve;
  final bool matchTextDirection;
  final bool allowDrawingOutsideViewBox;
  final String? semanticsLabel;

  /// Whether to exclude this widget from the semantics tree.
  final bool excludeFromSemantics;

  /// Optional cache key to use instead of auto-generated cache key.
  /// If provided, this will be used as the asset path in the cache key.
  final String? cacheKey;

  /// Optional cache manager instance. If not provided, the default singleton will be used.
  /// Can be any CacheManager - if it's a VectorAssetCacheManager, it will use the optimized getSvg() method.
  final CacheManager? cacheManager;

  @override
  State<CachedAssetVectorImage> createState() => _CachedAssetVectorImageState();
}

class _CachedAssetVectorImageState extends State<CachedAssetVectorImage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late CacheManager _cacheManager;

  svg.PictureInfo? _pictureInfo;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _cacheManager = widget.cacheManager ?? VectorAssetCacheManager();
    _animationController = AnimationController(
      duration: widget.fadeInDuration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: widget.fadeInCurve,
    );
    _loadSvg();
  }

  @override
  void didUpdateWidget(CachedAssetVectorImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheManager != widget.cacheManager) {
      _cacheManager = widget.cacheManager ?? VectorAssetCacheManager();
    }
    if (oldWidget.assetPath != widget.assetPath ||
        oldWidget.color != widget.color ||
        oldWidget.colorBlendMode != widget.colorBlendMode ||
        oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height) {
      _loadSvg();
    }
  }

  Future<void> _loadSvg() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final ColorFilter? colorFilter =
          widget.color != null ? ColorFilter.mode(widget.color!, widget.colorBlendMode) : null;

      // Use cacheKey if provided, otherwise use assetPath
      final assetPath = widget.cacheKey ?? widget.assetPath;

      // If it's a VectorAssetCacheManager, use the optimized getSvg() method
      final svg.PictureInfo pictureInfo;
      if (_cacheManager is VectorAssetCacheManager) {
        pictureInfo = await (_cacheManager as VectorAssetCacheManager).getSvg(
          assetPath,
          colorFilter: colorFilter,
          width: widget.width,
          height: widget.height,
        );
      } else {
        // Use generic CacheManager approach
        pictureInfo = await _loadSvgFromGenericCache(assetPath, colorFilter);
      }

      if (mounted) {
        setState(() {
          _pictureInfo = pictureInfo;
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

  /// Load SVG using generic CacheManager (fallback for non-VectorAssetCacheManager)
  Future<svg.PictureInfo> _loadSvgFromGenericCache(String assetPath, ui.ColorFilter? colorFilter) async {
    final key = _generateCacheKey(assetPath, colorFilter, widget.width, widget.height);
    
    try {
      // Try to get from file cache first
      final file = await _cacheManager.getSingleFile(
        'svg-asset://$assetPath',
        key: key,
      );
      
      final svgString = await file.readAsString();
      return await _parseSvgString(svgString);
    } catch (e) {
      // If not in cache, load from assets and cache it
      final String svgString = await rootBundle.loadString(assetPath);
      
      // Cache the SVG string
      await _cacheManager.putFile(
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

    if (_pictureInfo == null) {
      return const SizedBox.shrink();
    }

    Widget svgWidget = AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: CustomPaint(
            size: Size(
              widget.width ?? _pictureInfo!.size.width,
              widget.height ?? _pictureInfo!.size.height,
            ),
            painter: _SvgPicturePainter(
              picture: _pictureInfo!.picture,
              size: _pictureInfo!.size,
              alignment: widget.alignment,
              fit: widget.fit,
              matchTextDirection: widget.matchTextDirection,
              textDirection: widget.matchTextDirection ? Directionality.of(context) : null,
              allowDrawingOutsideViewBox: widget.allowDrawingOutsideViewBox,
            ),
          ),
        );
      },
    );

    // Apply semantics label if provided and not excluded from semantics
    if (!widget.excludeFromSemantics && widget.semanticsLabel != null) {
      svgWidget = Semantics(
        label: widget.semanticsLabel,
        child: svgWidget,
      );
    }

    // Exclude from semantics if requested
    if (widget.excludeFromSemantics) {
      svgWidget = ExcludeSemantics(child: svgWidget);
    }

    return svgWidget;
  }
}

class _SvgPicturePainter extends CustomPainter {
  _SvgPicturePainter({
    required this.picture,
    required this.size,
    required this.alignment,
    required this.fit,
    required this.matchTextDirection,
    required this.allowDrawingOutsideViewBox,
    this.textDirection,
  });

  final ui.Picture picture;
  final Size size;
  final AlignmentGeometry alignment;
  final BoxFit fit;
  final bool matchTextDirection;
  final TextDirection? textDirection;
  final bool allowDrawingOutsideViewBox;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final sizes = applyBoxFit(fit, size, canvasSize);
    final FittedSizes fittedSizes = FittedSizes(sizes.source, sizes.destination);

    final Rect outputRect = alignment.resolve(textDirection).inscribe(
          fittedSizes.destination,
          Offset.zero & canvasSize,
        );

    if (!allowDrawingOutsideViewBox) {
      canvas.save();
      canvas.clipRect(Offset.zero & canvasSize);
    }

    canvas.save();
    canvas.translate(outputRect.left, outputRect.top);

    if (matchTextDirection && textDirection == TextDirection.rtl) {
      canvas.translate(outputRect.width, 0);
      canvas.scale(-1, 1);
    }

    canvas.scale(
      outputRect.width / size.width,
      outputRect.height / size.height,
    );

    canvas.drawPicture(picture);
    canvas.restore();

    if (!allowDrawingOutsideViewBox) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SvgPicturePainter oldDelegate) {
    return oldDelegate.picture != picture ||
        oldDelegate.size != size ||
        oldDelegate.alignment != alignment ||
        oldDelegate.fit != fit ||
        oldDelegate.matchTextDirection != matchTextDirection ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.allowDrawingOutsideViewBox != allowDrawingOutsideViewBox;
  }
}
