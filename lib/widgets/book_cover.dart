import 'package:flutter/material.dart';

/// 讀冊書封縮圖；沒有圖時顯示書本 icon。點擊可開大圖。
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    this.url,
    this.largeUrl,
    this.width = 44,
    this.height = 60,
    this.seq,
    this.title,
  });

  final String? url;
  /// 點擊預覽用的大圖網址；未給則用 [url]
  final String? largeUrl;
  final double width;
  final double height;
  final int? seq;
  final String? title;

  void _openLarge(BuildContext context) {
    final preview = largeUrl ?? url;
    if (preview == null || preview.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    preview,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                right: 56,
                child: Text(
                  title?.isNotEmpty == true ? title! : '書封',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: '關閉',
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canPreview = (largeUrl ?? url)?.isNotEmpty == true;
    final cover = SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: url == null || url!.isEmpty
                  ? _placeholder(scheme)
                  : Image.network(
                      url!,
                      width: width,
                      height: height,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _placeholder(scheme),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return SizedBox(
                          width: width,
                          height: height,
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          if (seq != null)
            Positioned(
              right: -4,
              bottom: -4,
              child: CircleAvatar(
                radius: 10,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  '$seq',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (!canPreview) return cover;
    return GestureDetector(
      onTap: () => _openLarge(context),
      behavior: HitTestBehavior.opaque,
      child: cover,
    );
  }

  Widget _placeholder(ColorScheme scheme) {
    return SizedBox(
      width: width,
      height: height,
      child: Icon(
        Icons.menu_book_outlined,
        size: width * 0.45,
        color: scheme.outline,
      ),
    );
  }
}
