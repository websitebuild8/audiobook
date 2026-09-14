import 'dart:ui';
import 'package:flutter/material.dart';

/// A page scrubber with a large touch target and a drag-only page label.
class GlassPageScrollbar extends StatefulWidget {
  const GlassPageScrollbar(
      {super.key,
      required this.page,
      required this.pageCount,
      required this.onChanged});
  final int page;
  final int pageCount;
  final ValueChanged<int> onChanged;

  @override
  State<GlassPageScrollbar> createState() => _GlassPageScrollbarState();
}

class _GlassPageScrollbarState extends State<GlassPageScrollbar> {
  final _trackKey = GlobalKey();
  bool _pressed = false;
  int? _dragPage;
  double _grabOffset = 26;

  void _move(Offset globalPosition, double travel) {
    if (travel <= 0) return;
    final box = _trackKey.currentContext!.findRenderObject() as RenderBox;
    final fraction =
        ((box.globalToLocal(globalPosition).dy - _grabOffset) / travel)
            .clamp(0.0, 1.0);
    final page = 1 + (fraction * (widget.pageCount - 1)).round();
    if (page != _dragPage) {
      setState(() => _dragPage = page);
      widget.onChanged(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pageCount <= 1) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final current = (_dragPage ?? widget.page).clamp(1, widget.pageCount);
    return LayoutBuilder(builder: (context, constraints) {
      final travel = (constraints.maxHeight - 52).clamp(0.0, double.infinity);
      final top = (current - 1) / (widget.pageCount - 1) * travel;
      return Stack(key: _trackKey, clipBehavior: Clip.none, children: [
        Positioned(
          top: top,
          right: 0,
          width: 120,
          height: 52,
          child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              textDirection: TextDirection.ltr,
              children: [
                if (_pressed)
                  Expanded(
                      child: IgnorePointer(
                          child: _glass(
                    dark: dark,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      child: Text('$current / ${widget.pageCount}',
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 12,
                              color: dark
                                  ? Colors.white
                                  : const Color(0xFF173B36))),
                    ),
                  ))),
                const SizedBox(width: 8),
                Semantics(
                  label: 'PDF page',
                  value: '$current of ${widget.pageCount}',
                  increasedValue:
                      '${(current + 1).clamp(1, widget.pageCount)} of ${widget.pageCount}',
                  decreasedValue:
                      '${(current - 1).clamp(1, widget.pageCount)} of ${widget.pageCount}',
                  onIncrease: current < widget.pageCount
                      ? () => widget.onChanged(current + 1)
                      : null,
                  onDecrease:
                      current > 1 ? () => widget.onChanged(current - 1) : null,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      _grabOffset = details.localPosition.dy;
                      setState(() => _pressed = true);
                    },
                    onTapUp: (_) => setState(() => _pressed = false),
                    onTapCancel: () => setState(() => _pressed = false),
                    onVerticalDragStart: (_) => setState(() {
                      _pressed = true;
                      _dragPage = widget.page;
                    }),
                    onVerticalDragUpdate: (details) =>
                        _move(details.globalPosition, travel),
                    onVerticalDragEnd: (_) => setState(() {
                      _pressed = false;
                      _dragPage = null;
                    }),
                    onVerticalDragCancel: () => setState(() {
                      _pressed = false;
                      _dragPage = null;
                    }),
                    child: SizedBox(
                        width: 44,
                        height: 52,
                        child: Center(
                            child: _glass(
                          dark: dark,
                          child: SizedBox(
                              width: 28,
                              height: 48,
                              child: Icon(Icons.drag_handle_rounded,
                                  size: 20,
                                  color: dark
                                      ? Colors.white
                                      : const Color(0xFF173B36))),
                        ))),
                  ),
                ),
              ]),
        ),
      ]);
    });
  }

  Widget _glass({required bool dark, required Widget child}) => ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
              decoration: BoxDecoration(
                color:
                    (dark ? const Color(0xFF173B36) : const Color(0xFFF1FAF5))
                        .withValues(alpha: .82),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: .5)),
              ),
              child: child),
        ),
      );
}
