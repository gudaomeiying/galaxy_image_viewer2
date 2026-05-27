import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/image_model.dart';

/// 图片数据提供者，管理图片加载、排序和收藏状态
class ImageProvider extends ChangeNotifier {
  List<ImageModel> _images = [];
  List<ImageModel> _favorites = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _currentSortType = '按日期';
  String _currentFolder = '';

  List<ImageModel> get images => List.unmodifiable(_images);
  List<ImageModel> get favorites => List.unmodifiable(_favorites);
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get currentSortType => _currentSortType;
  String get currentFolder => _currentFolder;

  /// 请求相册权限
  Future<bool> requestPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      return true;
    } else if (ps.hasAccess) {
      return true;
    } else {
      _errorMessage = '需要相册访问权限才能使用此功能';
      notifyListeners();
      return false;
    }
  }

  /// 从设备相册加载图片
  Future<void> loadGalleryImages() async {
    _isLoading = true;
    _errorMessage = '';
    _currentFolder = '全部相册';
    notifyListeners();

    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final List<AssetPathEntity> albums =
          await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );

      if (albums.isEmpty) {
        _errorMessage = '未找到相册';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final List<AssetEntity> assets =
          await albums[0].getAssetListRange(start: 0, end: 200);

      _images = assets.asMap().entries.map((entry) {
        return ImageModel.fromAssetEntity(
          entry.value,
          sortIndex: entry.key,
        );
      }).toList();

      _updateFavorites();
      sortByDate();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '加载图片失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 从自定义文件夹加载图片
  Future<void> loadCustomFolderImages(String folderPath) async {
    _isLoading = true;
    _errorMessage = '';
    _currentFolder = folderPath;
    notifyListeners();

    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final List<AssetPathEntity> albums =
          await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: false,
      );

      AssetPathEntity? targetAlbum;
      for (final album in albums) {
        if (album.name == folderPath || album.id == folderPath) {
          targetAlbum = album;
          break;
        }
      }

      if (targetAlbum == null) {
        _errorMessage = '未找到文件夹: $folderPath';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final List<AssetEntity> assets =
          await targetAlbum.getAssetListRange(start: 0, end: 200);

      _images = assets.asMap().entries.map((entry) {
        return ImageModel.fromAssetEntity(
          entry.value,
          sortIndex: entry.key,
        );
      }).toList();

      _updateFavorites();
      sortByDate();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '加载文件夹图片失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新收藏列表
  void _updateFavorites() {
    _favorites = _images.where((img) => img.isFavorite).toList();
  }

  /// 切换收藏状态
  void toggleFavorite(String imageId) {
    final index = _images.indexWhere((img) => img.id == imageId);
    if (index != -1) {
      _images[index].isFavorite = !_images[index].isFavorite;
      _updateFavorites();
      notifyListeners();
    }
  }

  /// 按日期排序（最新在前）
  void sortByDate() {
    _currentSortType = '按日期';
    _images.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    _updateSortIndices();
    notifyListeners();
  }

  /// 按名称排序
  void sortByName() {
    _currentSortType = '按名称';
    _images.sort((a, b) => a.title.compareTo(b.title));
    _updateSortIndices();
    notifyListeners();
  }

  /// 按大小排序（宽 x 高面积）
  void sortBySize() {
    _currentSortType = '按大小';
    _images.sort((a, b) {
      final sizeA = a.width * a.height;
      final sizeB = b.width * b.height;
      return sizeB.compareTo(sizeA);
    });
    _updateSortIndices();
    notifyListeners();
  }

  /// 收藏优先排序
  void sortFavoritesFirst() {
    _currentSortType = '收藏优先';
    final favs = _images.where((img) => img.isFavorite).toList();
    final others = _images.where((img) => !img.isFavorite).toList();
    _images = [...favs, ...others];
    _updateSortIndices();
    notifyListeners();
  }

  /// 更新排序索引
  void _updateSortIndices() {
    for (int i = 0; i < _images.length; i++) {
      _images[i].sortIndex = i;
    }
  }

  /// 获取收藏图片列表
  List<ImageModel> getFavoritesList() {
    return _favorites;
  }

  /// 获取相册文件夹列表
  Future<List<String>> getAlbumFolders() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return [];

      final List<AssetPathEntity> albums =
          await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: false,
      );

      return albums.map((album) => album.name).toList();
    } catch (e) {
      return [];
    }
  }
}
