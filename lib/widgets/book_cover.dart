import 'package:flutter/material.dart';

/// 讀冊書封縮圖；沒有圖時顯示書本 icon。
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    this.url,
    this.width = 44,
    this.height = 60,
    this.seq,
  });

  final String? url;
  final double width;
  final double height;
  final int? seq;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
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
