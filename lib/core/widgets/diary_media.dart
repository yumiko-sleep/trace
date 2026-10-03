import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import 'bounce_tap.dart';
import '../../core/theme/app_scheme.dart';
import '../../core/theme/app_theme.dart';

/// 顶部悬浮的主操作按钮（渐变胶囊）。
class PillActionButton extends StatelessWidget {
  const PillActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.gradient,
    this.shadowColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final LinearGradient? gradient;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final LinearGradient g = gradient ?? c.primary;
    return BounceTap(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: g,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: (shadowColor ?? c.cyan).withValues(alpha: 0.38),
              blurRadius: 22,
              offset: const Offset(0, 10),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 只读的图片缩略图行（时间线卡片里用）。
///
/// 最多显示 [maxVisible] 张，多出来的用「+N」盖在最后一张上。
class DiaryThumbRow extends StatelessWidget {
  const DiaryThumbRow({
    super.key,
    required this.paths,
    required this.onTap,
    this.size = 86,
    this.maxVisible = 3,
  });

  final List<String> paths;
  final ValueChanged<int> onTap;
  final double size;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    if (paths.isEmpty) return const SizedBox.shrink();

    final int visible = paths.length > maxVisible ? maxVisible : paths.length;
    final int rest = paths.length - visible;

    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: visible,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          return BounceTap(
            onTap: () => onTap(index),
            haptic: false,
            scale: 0.96,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _Thumb(path: paths[index]),
                    if (rest > 0 && index == visible - 1)
                      Container(
                        color: c.ink.withValues(alpha: 0.55),
                        alignment: Alignment.center,
                        child: Text(
                          '+$rest',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 缩略图（限制解码尺寸，避免大图占内存）。
class _Thumb extends StatelessWidget {
  const _Thumb({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final File file = File(path);
    if (!file.existsSync()) {
      return Container(
        color: c.bgBottom,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          size: 20,
          color: c.inkFaint,
        ),
      );
    }
    return Image.file(
      file,
      fit: BoxFit.cover,
      cacheWidth: 320,
      errorBuilder: (_, __, ___) => Container(
        color: c.bgBottom,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          size: 20,
          color: c.inkFaint,
        ),
      ),
    );
  }
}

/// 编辑页里的图片网格：缩略图带删除按钮 + 末尾的「添加」方块。
class DiaryImageEditor extends StatelessWidget {
  const DiaryImageEditor({
    super.key,
    required this.paths,
    required this.onRemove,
    required this.onAdd,
    required this.onPreview,
    this.maxImages = 9,
    this.size = 90,
  });

  final List<String> paths;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;
  final ValueChanged<int> onPreview;
  final int maxImages;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        for (int i = 0; i < paths.length; i++)
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                BounceTap(
                  onTap: () => onPreview(i),
                  haptic: false,
                  scale: 0.96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: _Thumb(path: paths[i]),
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: BounceTap(
                    onTap: () => onRemove(i),
                    haptic: false,
                    scale: 0.9,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c.ink.withValues(alpha: 0.72),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (paths.length < maxImages)
          BounceTap(
            onTap: onAdd,
            haptic: false,
            scale: 0.94,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.line),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 24,
                    color: c.inkFaint,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${paths.length}/$maxImages',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 全屏看图：左右滑动切换，双指缩放，点空白关闭。
class PhotoViewPage extends StatefulWidget {
  const PhotoViewPage({
    super.key,
    required this.paths,
    this.initialIndex = 0,
  });

  final List<String> paths;
  final int initialIndex;

  @override
  State<PhotoViewPage> createState() => _PhotoViewPageState();
}

class _PhotoViewPageState extends State<PhotoViewPage> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.paths.length,
              onPageChanged: (int i) => setState(() => _index = i),
              itemBuilder: (BuildContext context, int i) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.file(
                      File(widget.paths[i]),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: _CircleButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          if (widget.paths.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 18,
              child: Text(
                '${_index + 1} / ${widget.paths.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BounceTap(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// 打开全屏看图。
Future<void> openPhotoView(
  BuildContext context, {
  required List<String> paths,
  int initialIndex = 0,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) =>
          PhotoViewPage(paths: paths, initialIndex: initialIndex),
      transitionsBuilder: (_, Animation<double> animation, __, Widget child) =>
          FadeTransition(
        opacity: CurveTween(curve: AppMotion.easeOut).animate(animation),
        child: child,
      ),
    ),
  );
}
