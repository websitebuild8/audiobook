import 'dart:ui';

import 'package:flutter/material.dart';

/// A bounded glass panel that keeps long Dhivehi notices readable and scrollable.
class ReaderNotice extends StatelessWidget {
  const ReaderNotice({super.key, required this.text, required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFF1F7F3) : const Color(0xFF173D30);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .28 : .12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .46,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: dark
                        ? [const Color(0xEC183D30), const Color(0xDA152C25)]
                        : [const Color(0xF5F6FCF8), const Color(0xDAE4F0E8)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: dark ? .24 : .8),
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            text,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.85,
                              color: foreground,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 24,
                            color: foreground,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 5,
                        left: 5,
                        child: IconButton(
                          tooltip: 'ބަންދުކުރައްވާ',
                          onPressed: onClose,
                          color: foreground,
                          icon: const Icon(Icons.close_rounded, size: 21),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
