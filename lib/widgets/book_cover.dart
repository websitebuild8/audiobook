import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_theme.dart';
import '../theme/category_theme.dart';

class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.compact = false});

  final Book book;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (book.coverAsset != null) {
      return Hero(
        tag: 'cover-${book.id}',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(compact ? 16 : 24),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            book.coverAsset!,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) =>
                _GeneratedCover(book: book, compact: compact),
          ),
        ),
      );
    }
    return _GeneratedCover(book: book, compact: compact);
  }
}

class _GeneratedCover extends StatelessWidget {
  const _GeneratedCover({required this.book, required this.compact});

  final Book book;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = CategoryTheme.forName(book.category).colors;
    return Hero(
      tag: 'cover-${book.id}',
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: palette,
            ),
            borderRadius: BorderRadius.circular(compact ? 16 : 24),
            boxShadow: [
              BoxShadow(
                color: palette.last.withValues(alpha: .22),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: -28,
                top: -22,
                child: Transform.rotate(
                  angle: math.pi / 8,
                  child: Container(
                    width: 95,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .13),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(45),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 14 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          book.hasAudio
                              ? Icons.headphones_rounded
                              : Icons.menu_book_rounded,
                          color: Colors.white,
                          size: compact ? 20 : 26,
                        ),
                        Container(
                          width: 28,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppTheme.gold,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      book.title,
                      maxLines: compact ? 3 : 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 16 : 22,
                        height: 1.55,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: compact ? 5 : 10),
                    Text(
                      book.category,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .72),
                        fontFamily: 'sans-serif',
                        fontSize: compact ? 10 : 12,
                        letterSpacing: .3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
