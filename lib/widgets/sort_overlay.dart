import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/image_model.dart';

/// 排序选项枚举
enum SortOption {
  date('按日期', Icons.calendar_today),
  name('按名称', Icons.sort_by_alpha),
  size('按大小', Icons.photo_size_select_large),
  favorites('收藏优先', Icons.favorite);

  const SortOption(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// 排序覆盖层，长按时显示，支持动画排序
class SortOverlay extends StatefulWidget {
  final List<ImageModel> images;
  final String currentSortType;
  final void Function(SortOption option) onSortSelected;
  final VoidCallback onClose;

  const SortOverlay({
    super.key,
    required this.images,
    required this.currentSortType,
    required this.onSortSelected,
    required this.onClose,
  });

  @override
  State<SortOverlay> createState() => SortOverlayState();
}

class SortOverlayState extends State<SortOverlay>
    with TickerProviderStateMixin {
  late AnimationController _overlayController;
  late Animation<double> _overlayAnimation;
  late AnimationController _thumbnailController;
  bool _isSorting = false;
  SortOption _selectedOption = SortOption.date;

  List<_ThumbnailPosition> _positions = [];

  @override
  void initState() {
    super.initState();
    _overlayController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _thumbnailController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _overlayAnimation = CurvedAnimation(
      parent: _overlayController,
      curve: Curves.easeOutCubic,
    );

    _selectedOption = _getSortOptionFromLabel(widget.currentSortType);
    _overlayController.forward();
  }

  SortOption _getSortOptionFromLabel(String label) {
    switch (label) {
      case '按名称':
        return SortOption.name;
      case '按大小':
        return SortOption.size;
      case '收藏优先':
        return SortOption.favorites;
      default:
        return SortOption.date;
    }
  }

  @override
  void dispose() {
    _overlayController.dispose();
    _thumbnailController.dispose();
    super.dispose();
  }

  void _performSort(SortOption option) {
    if (_isSorting) return;
    setState(() {
      _isSorting = true;
      _selectedOption = option;
    });

    _positions = widget.images.asMap().entries.map((entry) {
      return _ThumbnailPosition(
        imageId: entry.value.id,
        oldIndex: entry.key,
        newIndex: entry.key,
      );
    }).toList();

    widget.onSortSelected(option);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _thumbnailController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() {
            _isSorting = false;
          });
        }
      });
    });
  }

  void _close() {
    _overlayController.reverse().then((_) {
      widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _overlayAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _overlayAnimation.value,
          child: GestureDetector(
            onTap: _close,
            child: Container(
              color: Colors.black.withValues(alpha: 0.6 * _overlayAnimation.value),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(_overlayAnimation),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.85),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          child: BackdropFilter(
                            filter: _createBlurFilter(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 20,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '排序方式',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white70,
                                        ),
                                        onPressed: _close,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: SortOption.values.map((option) {
                                      final isSelected =
                                          _selectedOption == option;
                                      return _SortOptionButton(
                                        option: option,
                                        isSelected: isSelected,
                                        onTap: () => _performSort(option),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 20),

                                  SizedBox(
                                    height: 80,
                                    child: _isSorting
                                        ? _buildAnimatedThumbnails(screenSize)
                                        : _buildStaticThumbnails(),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  dynamic _createBlurFilter() {
    return const ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.transparent,
        BlendMode.dst,
      ),
      child: SizedBox.shrink(),
    );
  }

  Widget _buildStaticThumbnails() {
    if (widget.images.isEmpty) {
      return const Center(
        child: Text(
          '暂无图片',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: widget.images.length,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemBuilder: (context, index) {
        final image = widget.images[index];
        return _ThumbnailCard(
          image: image,
          size: 64,
        );
      },
    );
  }

  Widget _buildAnimatedThumbnails(Size screenSize) {
    if (widget.images.isEmpty) {
      return const Center(
        child: Text(
          '暂无图片',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _thumbnailController,
      builder: (context, child) {
        return Stack(
          children: widget.images.asMap().entries.map((entry) {
            final index = entry.key;
            final image = entry.value;
            final animationValue = Curves.easeOutCubic
                .transform(_thumbnailController.value);

            final double targetX = index * 72.0;
            final oldPos = _positions.isNotEmpty &&
                    _positions.any((p) => p.imageId == image.id)
                ? _positions
                    .firstWhere((p) => p.imageId == image.id)
                    .oldIndex *
                    72.0
                : targetX;
            final currentX = oldPos + (targetX - oldPos) * animationValue;

            return Positioned(
              left: currentX,
              top: 0,
              child: _ThumbnailCard(
                image: image,
                size: 64,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// 排序选项按钮
class _SortOptionButton extends StatelessWidget {
  final SortOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOptionButton({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurple.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.deepPurpleAccent
                : Colors.white.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              option.icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              option.label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 缩略图卡片
class _ThumbnailCard extends StatelessWidget {
  final ImageModel image;
  final double size;

  const _ThumbnailCard({
    required this.image,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: size,
          height: size,
          color: Colors.grey.shade800,
          child: image.assetEntity != null
              ? FutureBuilder<Uint8List?>(
                  future: image.assetEntity!.thumbnailDataWithSize(
                    const ThumbnailSize(128, 128),
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.data != null) {
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        width: size,
                        height: size,
                      );
                    }
                    return Container(
                      width: size,
                      height: size,
                      color: Colors.grey.shade800,
                      child: const Center(
                        child: Icon(
                          Icons.image,
                          color: Colors.white24,
                          size: 24,
                        ),
                      ),
                    );
                  },
                )
              : const Center(
                  child: Icon(
                    Icons.image,
                    color: Colors.white24,
                    size: 24,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 缩略图位置记录
class _ThumbnailPosition {
  final String imageId;
  final int oldIndex;
  int newIndex;

  _ThumbnailPosition({
    required this.imageId,
    required this.oldIndex,
    this.newIndex = 0,
  });
}
