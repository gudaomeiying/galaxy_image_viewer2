import 'package:photo_manager/photo_manager.dart';

/// 图片数据模型
class ImageModel {
  final String id;
  final String path;
  final AssetEntity? assetEntity;
  bool isFavorite;
  final DateTime dateAdded;
  final int width;
  final int height;
  final String title;
  int sortIndex;

  ImageModel({
    required this.id,
    required this.path,
    this.assetEntity,
    this.isFavorite = false,
    required this.dateAdded,
    this.width = 0,
    this.height = 0,
    this.title = '',
    this.sortIndex = 0,
  });

  /// 从 AssetEntity 工厂方法创建 ImageModel
  factory ImageModel.fromAssetEntity(AssetEntity entity, {int sortIndex = 0}) {
    return ImageModel(
      id: entity.id,
      path: entity.relativePath ?? '',
      assetEntity: entity,
      isFavorite: false,
      dateAdded: entity.createDateTime,
      width: entity.width,
      height: entity.height,
      title: entity.title ?? '未命名',
      sortIndex: sortIndex,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'isFavorite': isFavorite,
      'dateAdded': dateAdded.toIso8601String(),
      'width': width,
      'height': height,
      'title': title,
      'sortIndex': sortIndex,
    };
  }

  /// 从 JSON 创建
  factory ImageModel.fromJson(Map<String, dynamic> json) {
    return ImageModel(
      id: json['id'] as String? ?? '',
      path: json['path'] as String? ?? '',
      assetEntity: null,
      isFavorite: json['isFavorite'] as bool? ?? false,
      dateAdded: json['dateAdded'] != null
          ? DateTime.parse(json['dateAdded'] as String)
          : DateTime.now(),
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      sortIndex: json['sortIndex'] as int? ?? 0,
    );
  }

  /// 复制并修改部分字段
  ImageModel copyWith({
    String? id,
    String? path,
    AssetEntity? assetEntity,
    bool? isFavorite,
    DateTime? dateAdded,
    int? width,
    int? height,
    String? title,
    int? sortIndex,
  }) {
    return ImageModel(
      id: id ?? this.id,
      path: path ?? this.path,
      assetEntity: assetEntity ?? this.assetEntity,
      isFavorite: isFavorite ?? this.isFavorite,
      dateAdded: dateAdded ?? this.dateAdded,
      width: width ?? this.width,
      height: height ?? this.height,
      title: title ?? this.title,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ImageModel(id: $id, title: $title, isFavorite: $isFavorite)';
  }
}
