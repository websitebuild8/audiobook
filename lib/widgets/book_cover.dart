import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/category_theme.dart';

class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.compact = false});

  final Book book;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cover = book.coverAsset == null
        ? _GeneratedFace(book: book, compact: compact)
        : Image.asset(
            book.coverAsset!,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) =>
                _GeneratedFace(book: book, compact: compact),
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 7 : 10, 3, compact ? 9 : 14, 12),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .001)
          ..rotateY(-.035),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFE8E2D7),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(5),
              bottomRight: Radius.circular(5),
              topLeft: Radius.circular(2),
              bottomLeft: Radius.circular(2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .65),
                blurRadius: compact ? 15 : 24,
                spreadRadius: 1,
                offset: Offset(compact ? 7 : 10, compact ? 10 : 15),
              ),
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(
                      alpha: .12,
                    ),
                blurRadius: 20,
                offset: const Offset(-3, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: -3,
                top: 5,
                bottom: 5,
                width: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E2D7),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF9D978D), offset: Offset(1, 0)),
                    ],
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                  topLeft: Radius.circular(1),
                  bottomLeft: Radius.circular(1),
                ),
                child: cover,
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: compact ? 9 : 13,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: .72),
                        Colors.black.withValues(alpha: .16),
                        Colors.white.withValues(alpha: .09),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: compact ? 11 : 16,
                top: 0,
                bottom: 0,
                width: 1,
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: .14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeneratedFace extends StatelessWidget {
  const _GeneratedFace({required this.book, required this.compact});

  final Book book;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = CategoryTheme.forName(
      book.category,
      dark: Theme.of(context).brightness == Brightness.dark,
    ).colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: palette,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 80 || constraints.maxHeight < 150) {
            return Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    book.hasAudio
                        ? Icons.headphones_rounded
                        : Icons.menu_book_rounded,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 16,
                  ),
                  const SizedBox(height: 5),
                  Flexible(
                    child: Text(
                      book.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return _GeneratedFaceDetails(book: book, compact: compact);
        },
      ),
    );
  }
}

class _GeneratedFaceDetails extends StatelessWidget {
  const _GeneratedFaceDetails({required this.book, required this.compact});

  final Book book;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: -42,
          top: -35,
          child: Transform.rotate(
            angle: math.pi / 7,
            child: Icon(
              Icons.auto_stories_rounded,
              size: compact ? 130 : 190,
              color: Colors.white.withValues(alpha: .055),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 17 : 25,
            compact ? 13 : 22,
            compact ? 12 : 18,
            compact ? 13 : 22,
          ),
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
                    color: Theme.of(context).colorScheme.secondary,
                    size: compact ? 18 : 25,
                  ),
                  Container(
                    width: 26,
                    height: 2,
                    color: Colors.white.withValues(alpha: .7),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                book.title,
                maxLines: compact ? 4 : 6,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 15 : 22,
                  height: 1.55,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Divider(color: Colors.white.withValues(alpha: .25)),
              Text(
                book.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .68),
                  fontSize: compact ? 9 : 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
