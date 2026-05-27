import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/image_model.dart';
import '../providers/image_provider.dart' as img_provider;
import '../widgets/favorite_button.dart';

/// 全屏图片查看器，支持滑动切换、双击缩放、捏合缩放
class ImageDetailScreen extends StatefulWidget {
  final List<ImageModel> images;
  final int initialIndex;

  const ImageDetailScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late TransformationController _transformationController;
  int _currentIndex = 0;
  bool _showControls = true;
  late AnimationController _controlsController;
  late Animation<double> _controlsAnimation;
  late AnimationController _pageIndicatorController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _transformationController = TransformationController();

    _controlsController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsController,
      curve: Curves.easeOutCubic,
    );
    _controlsController.forward();

    _pageIndicatorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    _controlsController.dispose();
    _pageIndicatorController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _controlsController.forward();
    } else {
      _controlsController.reverse();
    }
  }

  void _toggleFavorite() {
    final provider =
        Provider.of<img_provider.ImageProvider>(context, listen: false);
    provider.toggleFavorite(widget.images[_currentIndex].id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: _toggleControls,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                _transformationController.value = Matrix4.identity();
                _pageIndicatorController.forward(from: 0.0);
              },
              itemBuilder: (context, index) {
                return _ZoomableImage(
                  image: widget.images[index],
                  transformationController: _transformationController,
                );
              },
            ),
          ),

          // 顶部控制栏
          AnimatedBuilder(
            animation: _controlsAnimation,
            builder: (context, child) {
              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _controlsAnimation.value,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      -50 * (1 - _controlsAnimation.value),
                    ),
                    child: child,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                right: 8,
                bottom: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      '${_currentIndex + 1} / ${widget.images.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Consumer<img_provider.ImageProvider>(
                    builder: (context, provider, child) {
                      final image = widget.images[_currentIndex];
                      return FavoriteButton(
                        isFavorite: image.isFavorite,
                        onTap: _toggleFavorite,
                        size: 28,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 底部页面指示器
          AnimatedBuilder(
            animation: _controlsAnimation,
            builder: (context, child) {
              return Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _controlsAnimation.value,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      50 * (1 - _controlsAnimation.value),
                    ),
                    child: child,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: _currentIndex > 0
                        ? () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        : null,
                  ),
                  const SizedBox(width: 16),
                  _buildPageIndicator(),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed:
                        _currentIndex < widget.images.length - 1
                            ? () {
                                _pageController.nextPage(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    if (widget.images.length <= 1) return const SizedBox.shrink();

    final int startIndex;
    final int endIndex;

    if (widget.images.length <= 7) {
      startIndex = 0;
      endIndex = widget.images.length;
    } else if (_currentIndex < 3) {
      startIndex = 0;
      endIndex = 7;
    } else if (_currentIndex > widget.images.length - 4) {
      startIndex = widget.images.length - 7;
      endIndex = widget.images.length;
    } else {
      startIndex = _currentIndex - 3;
      endIndex = _currentIndex + 4;
    }

    return AnimatedBuilder(
      animation: _pageIndicatorController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(endIndex - startIndex, (i) {
            final dotIndex = startIndex + i;
            final isActive = dotIndex == _currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.deepPurpleAccent
                    : Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color:
                              Colors.deepPurpleAccent.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        );
      },
    );
  }
}

/// 可缩放的图片组件
class _ZoomableImage extends StatefulWidget {
  final ImageModel image;
  final TransformationController transformationController;

  const _ZoomableImage({
    required this.image,
    required this.transformationController,
  });

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _doubleTapController;
  TapDownDetails? _tapDownDetails;

  @override
  void initState() {
    super.initState();
    _doubleTapController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _doubleTapController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final Matrix4 endMatrix;
    if (widget.transformationController.value != Matrix4.identity()) {
      endMatrix = Matrix4.identity();
    } else {
      final position = _tapDownDetails?.localPosition ??
          const Offset(200.0, 200.0);
      endMatrix = Matrix4.identity()
        ..setEntry(0, 3, -position.dx * 1.5)
        ..setEntry(1, 3, -position.dy * 1.5)
        ..setEntry(0, 0, 2.5)
        ..setEntry(1, 1, 2.5);
    }

    final animation = Matrix4Tween(
      begin: widget.transformationController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(
      parent: _doubleTapController,
      curve: Curves.easeOutCubic,
    ));

    void listener() {
      widget.transformationController.value = animation.value;
    }

    _doubleTapController.addListener(listener);
    _doubleTapController.forward(from: 0.0).then((_) {
      _doubleTapController.removeListener(listener);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: GestureDetector(
          onDoubleTapDown: (details) {
            _tapDownDetails = details;
          },
          onDoubleTap: _handleDoubleTap,
          child: InteractiveViewer(
            transformationController: widget.transformationController,
            minScale: 0.5,
            maxScale: 5.0,
            child: _buildFullImage(),
          ),
        ),
      ),
    );
  }

  Widget _buildFullImage() {
    if (widget.image.assetEntity != null) {
      return FutureBuilder<Uint8List?>(
        future: widget.image.assetEntity!.originBytes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.deepPurpleAccent,
              ),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    color: Colors.white24,
                    size: 64,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '图片加载失败',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            );
          }
          return Hero(
            tag: 'image_${widget.image.id}',
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          );
        },
      );
    }
    return const Center(
      child: Icon(
        Icons.image,
        color: Colors.white24,
        size: 64,
      ),
    );
  }
}
