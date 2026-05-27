import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../models/image_model.dart';
import '../providers/image_provider.dart' as img_provider;
import '../screens/image_detail_screen.dart';
import 'sort_overlay.dart';

/// 图片网格组件，支持3D卡片翻转效果、交错入场动画、长按排序
class ImageGrid extends StatefulWidget {
  final List<ImageModel> images;
  final bool showFavoritesOnly;

  const ImageGrid({
    super.key,
    required this.images,
    this.showFavoritesOnly = false,
  });

  @override
  State<ImageGrid> createState() => ImageGridState();
}

class ImageGridState extends State<ImageGrid>
    with TickerProviderStateMixin {
  bool _showSortOverlay = false;

  late List<AnimationController> _entranceControllers;
  late List<Animation<double>> _entranceAnimations;

  @override
  void initState() {
    super.initState();
    _initEntranceAnimations();
  }

  void _initEntranceAnimations() {
    final count = widget.images.length;
    _entranceControllers = List.generate(
      count,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      ),
    );
    _entranceAnimations = _entranceControllers.map((controller) {
      return CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      );
    }).toList();

    for (int i = 0; i < count; i++) {
      Future.delayed(
        Duration(milliseconds: i * 60),
        () {
          if (mounted && i < _entranceControllers.length) {
            _entranceControllers[i].forward();
          }
        },
      );
    }
  }

  @override
  void didUpdateWidget(ImageGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.length != widget.images.length ||
        oldWidget.images != widget.images) {
      for (final controller in _entranceControllers) {
        controller.dispose();
      }
      _initEntranceAnimations();
    }
  }

  @override
  void dispose() {
    for (final controller in _entranceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onSortSelected(SortOption option) {
    final provider =
        Provider.of<img_provider.ImageProvider>(context, listen: false);
    switch (option) {
      case SortOption.date:
        provider.sortByDate();
        break;
      case SortOption.name:
        provider.sortByName();
        break;
      case SortOption.size:
        provider.sortBySize();
        break;
      case SortOption.favorites:
        provider.sortFavoritesFirst();
        break;
    }
  }

  void _onTapImage(BuildContext context, ImageModel image, int index) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) {
          return ImageDetailScreen(
            images: widget.images,
            initialIndex: index,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.showFavoritesOnly ? Icons.favorite_border : Icons.image,
              size: 80,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              widget.showFavoritesOnly ? '暂无收藏图片' : '暂无图片',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: widget.images.length,
          itemBuilder: (context, index) {
            final image = widget.images[index];
            final animation = index < _entranceAnimations.length
                ? _entranceAnimations[index]
                : null;

            return _ImageCard(
              image: image,
              index: index,
              animation: animation,
              onTap: () => _onTapImage(context, image, index),
              onLongPress: () {
                setState(() {
                  _showSortOverlay = true;
                });
              },
            );
          },
        ),

        if (_showSortOverlay)
          SortOverlay(
            images: widget.images,
            currentSortType: Provider.of<img_provider.ImageProvider>(context)
                .currentSortType,
            onSortSelected: _onSortSelected,
            onClose: () {
              setState(() {
                _showSortOverlay = false;
              });
            },
          ),
      ],
    );
  }
}

/// 3D 透视卡片效果
class _ImageCard extends StatefulWidget {
  final ImageModel image;
  final int index;
  final Animation<double>? animation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ImageCard({
    required this.image,
    required this.index,
    this.animation,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<_ImageCard> {
  double _rotationY = 0.0;
  double _scale = 1.0;

  static const double _perspective = 0.003;

  @override
  Widget build(BuildContext context) {
    Widget cardContent = GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onHorizontalDragUpdate: (details) {
        setState(() {
          _rotationY = (details.delta.dx * 0.5).clamp(-0.5, 0.5);
          _scale = 1.02;
        });
      },
      onHorizontalDragEnd: (_) {
        setState(() {
          _rotationY = 0.0;
          _scale = 1.0;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: Offset(
                _rotationY * 10,
                4,
              ),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImageContent(),

              if (widget.image.isFavorite)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    widget.image.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    cardContent = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, _perspective)
        ..rotateY(_rotationY)
        ..setEntry(0, 0, _scale)
        ..setEntry(1, 1, _scale),
      child: cardContent,
    );

    if (widget.animation != null) {
      cardContent = AnimatedBuilder(
        animation: widget.animation!,
        builder: (context, child) {
          final animValue = widget.animation!.value;
          return Transform.scale(
            scale: 0.6 + 0.4 * animValue,
            child: Opacity(
              opacity: animValue,
              child: child,
            ),
          );
        },
        child: cardContent,
      );
    }

    return Hero(
      tag: 'image_${widget.image.id}',
      child: cardContent,
    );
  }

  Widget _buildImageContent() {
    if (widget.image.assetEntity != null) {
      return FutureBuilder<Uint8List?>(
        future: widget.image.assetEntity!.thumbnailDataWithSize(
          const ThumbnailSize(300, 300),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerPlaceholder();
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _buildErrorPlaceholder();
          }
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        },
      );
    }
    return _buildErrorPlaceholder();
  }

  Widget _buildShimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade600,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(
            Icons.image,
            color: Colors.white24,
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey.shade900,
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.white24,
          size: 32,
        ),
      ),
    );
  }
}
