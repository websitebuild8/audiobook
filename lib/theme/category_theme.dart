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
        colors: [Color(0xFF9A6A3A), Color(0xFF3F2B20)],
        tint: Color(0xFFF4E8D8),
        icon: Icons.local_library_rounded,
      );
    }
    if (category.contains('މީޒާން')) {
      return const CategoryTheme(
        colors: [Color(0xFF397A9A), Color(0xFF173D52)],
        tint: Color(0xFFDDEEF5),
        icon: Icons.balance_rounded,
      );
    }
    if (category.contains('ފުރްސާން')) {
      return const CategoryTheme(
        colors: [Color(0xFF17806F), Color(0xFF123F39)],
        tint: Color(0xFFDDF2EA),
        icon: Icons.auto_stories_rounded,
      );
    }
    return const CategoryTheme(
      colors: [Color(0xFF0D6B5D), Color(0xFF173B36)],
      tint: Color(0xFFDDF2EA),
      icon: Icons.library_books_rounded,
    );
  }
}
