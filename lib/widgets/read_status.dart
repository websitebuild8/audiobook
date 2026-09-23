import 'package:flutter/material.dart';

import '../services/progress_service.dart';

/// User-confirmed completion, independent of page position and downloads.
class ReadStatus extends StatelessWidget {
  const ReadStatus({super.key, required this.bookId, this.interactive = false});
  final String bookId;
  final bool interactive;

  Future<void> _change(BuildContext context, bool read) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(read ? Icons.menu_book_rounded : Icons.task_alt_rounded),
        title: Text(read
            ? 'ނުކިޔާ ފޮތެއްގެ ގޮތުގައި ފާހަގަކުރަން؟'
            : 'ފޮތް ކިޔާ ނިމިއްޖެތަ؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ކެންސަލް')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ފާހަގަކުރޭ')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ProgressService.setRead(bookId, !read);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(read
            ? 'ނުކިޔާ ފޮތެއްގެ ގޮތުގައި ފާހަގަކުރެވިއްޖެ'
            : 'ކިޔާ ނިމުނު ފޮތެއްގެ ގޮތުގައި ފާހަގަކުރެވިއްޖެ'),
      ));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ސޭވް ނުކުރެވުނު. އަލުން ކުރައްވާ.')));
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: ProgressService.readStatusChanges,
        builder: (context, revision, _) => FutureBuilder<bool>(
          future: ProgressService.isRead(bookId),
          builder: (context, snapshot) {
            final read = snapshot.data ?? false;
            final label =
                read ? 'ކިޔާ ނިމިއްޖެ' : 'ކިޔާ ނިމުނު ގޮތުގައި ފާހަގަކުރޭ';
            if (interactive) {
              return IconButton(
                tooltip: label,
                onPressed:
                    snapshot.hasData ? () => _change(context, read) : null,
                icon: Icon(
                    read
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    color: read
                        ? const Color(0xFF168343)
                        : Theme.of(context).colorScheme.onSurfaceVariant),
              );
            }
            if (!read) return const SizedBox.shrink();
            return Tooltip(
              message: label,
              child: Semantics(
                  label: label,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 6)
                        ]),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF168343), size: 24),
                  )),
            );
          },
        ),
      );
}
