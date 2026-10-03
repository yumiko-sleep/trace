import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 日记配图的文件存储。
///
/// 设计：数据库里只存**文件路径**，图片本体放在 App 私有目录
/// （`<应用文档目录>/diary_images/`），卸载 App 时一起清掉，
/// 也不会出现在用户的相册里。
class ImageStorage {
  const ImageStorage._();

  static const String _folderName = 'diary_images';

  /// 压缩参数：最长边 1600px、质量 82，足够看清内容又不会太占空间。
  static const int maxWidth = 1600;
  static const int quality = 82;

  static Future<Directory> _dir() async => directory();

  /// 配图所在目录（不存在时创建）。孤儿图片清理等维护操作也会用它。
  static Future<Directory> directory() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(docs.path, _folderName));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 从相册选图（可多选），自动压缩，并复制进 App 私有目录。
  ///
  /// 返回新文件的路径列表；用户取消时返回空列表。
  static Future<List<String>> pickAndSave({int limit = 9}) async {
    if (limit <= 0) return const <String>[];

    final ImagePicker picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage(
      maxWidth: maxWidth.toDouble(),
      imageQuality: quality,
      limit: limit,
    );
    if (picked.isEmpty) return const <String>[];

    final Directory dir = await _dir();
    final List<String> saved = <String>[];
    for (int i = 0; i < picked.length && i < limit; i++) {
      final XFile file = picked[i];
      final String ext = p.extension(file.path).isEmpty
          ? '.jpg'
          : p.extension(file.path).toLowerCase();
      final String name =
          '${DateTime.now().millisecondsSinceEpoch}_${i}_${saved.length}$ext';
      final File target = File(p.join(dir.path, name));
      await File(file.path).copy(target.path);
      saved.add(target.path);
    }
    return saved;
  }

  /// 删除一张图片（用户主动移除配图时调用）。
  static Future<void> delete(String path) async {
    try {
      final File file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // 文件已被清理时忽略
    }
  }

  /// 删除多张。
  static Future<void> deleteAll(Iterable<String> paths) async {
    for (final String path in paths) {
      await delete(path);
    }
  }
}
