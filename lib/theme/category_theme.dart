import 'package:flutter/material.dart';

class CategoryTheme {
  const CategoryTheme({
    required this.colors,
    required this.tint,
    required this.icon,
  });

  final List<Color> colors;
  final Color tint;
  final IconData icon;

  Color get primary => colors.first;

  static CategoryTheme forName(String category) {
    if (category.contains('ފިތިޔާ')) {
      return const CategoryTheme(
        colors: [Color(0xFF1C7A61), Color(0xFF0C2921)],
        tint: Color(0xFF163C32),
        icon: Icons.local_library_rounded,
      );
    }
    if (category.contains('މީޒާން')) {
      return const CategoryTheme(
        colors: [Color(0xFF257D6A), Color(0xFF102F28)],
        tint: Color(0xFF17372F),
        icon: Icons.balance_rounded,
      );
    }
    if (category.contains('ފުރްސާން')) {
      return const CategoryTheme(
        colors: [Color(0xFF159579), Color(0xFF0B362C)],
        tint: Color(0xFF153F35),
        icon: Icons.auto_stories_rounded,
      );
    }
    return const CategoryTheme(
      colors: [Color(0xFF0D6B5D), Color(0xFF173B36)],
      tint: Color(0xFF163C32),
      icon: Icons.library_books_rounded,
    );
  }
}
