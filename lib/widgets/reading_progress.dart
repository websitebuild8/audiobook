import 'package:flutter/material.dart';
import '../services/progress_service.dart';

class ReadingProgress extends StatelessWidget {
  const ReadingProgress({super.key, required this.bookIds});
  final List<String> bookIds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<int>(
      valueListenable: ProgressService.readStatusChanges,
      builder: (context, _, child) =>
          FutureBuilder<({int completed, int total})>(
        future: ProgressService.readingSummary(bookIds),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.total == 0) {
            return const SizedBox.shrink();
          }
          final progress = snapshot.data!;
          final value = progress.completed / progress.total;
          final count = '${progress.completed}/${progress.total}';
          return Container(
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(Icons.task_alt_rounded, size: 19, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('ކިޔައި ނިމިފައި',
                          style: Theme.of(context).textTheme.bodyMedium)),
                  const SizedBox(width: 8),
                  Text(count,
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: value),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 350),
                  builder: (context, value, child) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(8),
                    color: scheme.primary,
                    backgroundColor: scheme.primary.withValues(alpha: .12),
                    semanticsLabel: 'ކިޔައި ނިމިފައި',
                    semanticsValue: count,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
