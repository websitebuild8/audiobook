import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/book.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_player_panel.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book, this.initialPage});

  final Book book;
  final int? initialPage;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _pdfController = PdfViewerController();
  int _page = 1;
  int _pageCount = 0;
  bool _bookmarked = false;
  bool _controlsVisible = true;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final page =
        widget.initialPage ?? await ProgressService.pageFor(widget.book.id);
    final bookmarked = await ProgressService.isBookmarked(widget.book.id, page);
    if (!mounted) return;
    setState(() {
      _page = page;
      _bookmarked = bookmarked;
      _ready = true;
    });
  }

  Future<void> _onPageChanged(int? page) async {
    if (page == null || page == _page) return;
    final bookmarked = await ProgressService.isBookmarked(widget.book.id, page);
    if (!mounted) return;
    setState(() {
      _page = page;
      _bookmarked = bookmarked;
    });
    await ProgressService.savePage(widget.book.id, page);
  }

  Future<void> _toggleBookmark() async {
    final value = await ProgressService.toggleBookmark(widget.book.id, _page);
    if (!mounted) return;
    setState(() => _bookmarked = value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          value ? 'ބުކްމާކް ކުރެވިއްޖެ' : 'ބުކްމާކް ފުހެވިއްޖެ',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    ProgressService.savePage(widget.book.id, _page);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: PdfViewer.asset(
                    widget.book.pdfAsset,
                    controller: _pdfController,
                    initialPageNumber: _page,
                    params: PdfViewerParams(
                      margin: 10,
                      backgroundColor: const Color(0xFF121715),
                      pageDropShadow: BoxShadow(
                        color: Colors.black.withValues(alpha: .12),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                      onPageChanged: _onPageChanged,
                      onViewerReady: (document, controller) {
                        if (mounted) {
                          setState(() => _pageCount = controller.pageCount);
                        }
                      },
                      onGeneralTap: (context, controller, details) {
                        setState(() => _controlsVisible = !_controlsVisible);
                        return false;
                      },
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  top: _controlsVisible ? 0 : -116,
                  left: 0,
                  right: 0,
                  child: _ReaderHeader(
                    title: widget.book.title,
                    page: _page,
                    pageCount: _pageCount,
                    bookmarked: _bookmarked,
                    onBack: () => Navigator.of(context).pop(),
                    onBookmark: _toggleBookmark,
                  ),
                ),
                if (widget.book.hasAudio)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    left: 12,
                    right: 12,
                    bottom: _controlsVisible ? 10 : -190,
                    child: AudioPlayerPanel(book: widget.book),
                  ),
                if (!widget.book.hasAudio)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    bottom: _controlsVisible ? 22 : -60,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _PagePill(page: _page, count: _pageCount),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ReaderHeader extends StatelessWidget {
  const _ReaderHeader({
    required this.title,
    required this.page,
    required this.pageCount,
    required this.bookmarked,
    required this.onBack,
    required this.onBookmark,
  });
  final String title;
  final int page;
  final int pageCount;
  final bool bookmarked;
  final VoidCallback onBack;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface.withValues(alpha: .97),
      elevation: 1,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      pageCount > 0
                          ? 'ޞަފްޙާ $page / $pageCount'
                          : 'ޞަފްޙާ $page',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'ބުކްމާކް',
                onPressed: onBookmark,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    bookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    key: ValueKey(bookmarked),
                    color: bookmarked ? AppTheme.gold : Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _PagePill extends StatelessWidget {
  const _PagePill({required this.page, required this.count});
  final int page;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.ink.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        count > 0 ? '$page / $count' : '$page',
        textDirection: TextDirection.ltr,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'sans-serif',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
