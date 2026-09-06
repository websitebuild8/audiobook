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

  static CategoryTheme forName(String category, {required bool dark}) {
    if (category.contains('ފިތިޔާ')) {
      return CategoryTheme(
        colors: dark
            ? const [Color(0xFF1C7A61), Color(0xFF0C2921)]
            : const [Color(0xFF9A6A3A), Color(0xFF3F2B20)],
        tint: dark ? const Color(0xFF163C32) : const Color(0xFFF4E8D8),
        icon: Icons.local_library_rounded,
      );
    }
    if (category.contains('މީޒާން')) {
      return CategoryTheme(
        colors: dark
            ? const [Color(0xFF257D6A), Color(0xFF102F28)]
            : const [Color(0xFF397A9A), Color(0xFF173D52)],
        tint: dark ? const Color(0xFF17372F) : const Color(0xFFDDEEF5),
        icon: Icons.balance_rounded,
      );
    }
    if (category.contains('ފުރްސާން')) {
      return CategoryTheme(
        colors: dark
            ? const [Color(0xFF159579), Color(0xFF0B362C)]
            : const [Color(0xFF168071), Color(0xFF123F39)],
        tint: dark ? const Color(0xFF153F35) : const Color(0xFFDDF2EA),
        icon: Icons.auto_stories_rounded,
      );
    }
    if (category.contains('އެހެނިހެން')) {
      return CategoryTheme(
        colors: dark
            ? const [Color(0xFF477B68), Color(0xFF172D26)]
            : const [Color(0xFF687E74), Color(0xFF33453D)],
        tint: dark ? const Color(0xFF20372F) : const Color(0xFFE5ECE8),
        icon: Icons.collections_bookmark_rounded,
      );
    }
    return CategoryTheme(
      colors: dark
          ? const [Color(0xFF0D6B5D), Color(0xFF173B36)]
          : const [Color(0xFF168071), Color(0xFF123F39)],
      tint: dark ? const Color(0xFF163C32) : const Color(0xFFDDF2EA),
      icon: Icons.library_books_rounded,
    );
  }
}
