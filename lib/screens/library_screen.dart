import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/catalog_service.dart';
import '../services/download_service.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';
import '../theme/category_theme.dart';
import '../widgets/book_cover.dart';
import '../widgets/reading_progress.dart';
import '../widgets/app_glass.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/audio_player_sheet.dart';
import '../services/audiobook_audio_handler.dart';
import 'reader_screen.dart';
import 'privacy_policy_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.darkMode,
    required this.onToggleTheme,
  });

  final bool darkMode;
  final VoidCallback onToggleTheme;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const _booksPerPage = 10;
  late Future<List<Book>> _catalog = CatalogService.load();
  final _search = TextEditingController();
  String? _category;
  int _tabIndex = 0;
  int _bookPage = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(Book book, [int? initialPage]) async {
    final localBook = await DownloadService.instance.localBook(book);
    if (!mounted) return;
    if (localBook == null) {
      await _showDownloadPrompt(book);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(book: localBook, initialPage: initialPage),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showDownloadPrompt(Book book) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ފޮތް ޑައުންލޯޑުކުރައްވާ',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                book.hasAudio
                    ? 'PDF ޑައުންލޯޑުވާނެ. އޯޑިއޯ ބައިތައް ވަކިވަކިން ޑައުންލޯޑުކުރެވޭނެ.'
                    : 'PDF ޑައުންލޯޑުވުމުން އޮފްލައިންގައި ކިޔެވޭނެ.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (book.pdfFileSize > 0) ...[
                const SizedBox(height: 8),
                Text(
                  _formatBytes(book.pdfFileSize),
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  DownloadService.instance.download(book);
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('PDF ޑައުންލޯޑުކުރައްވާ'),
              ),
              if (book.hasAudio) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showAudioPlayerSheet(context, book);
                  },
                  icon: const Icon(Icons.headphones_rounded),
                  label: const Text('އޯޑިއޯ ބައިތައް'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshCatalog() async {
    final refreshed = CatalogService.load(refresh: true);
    setState(() => _catalog = refreshed);
    await refreshed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        bottom: true,
        child: RefreshIndicator(
          onRefresh: _refreshCatalog,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            reverseDuration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final fade = CurvedAnimation(
                parent: animation,
                curve: const Interval(0.12, 1),
              );
              return FadeTransition(
                opacity: fade,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(.035, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_tabIndex),
              child: FutureBuilder<List<Book>>(
                future: _catalog,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _ErrorState(onRetry: () => setState(() {}));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final books = snapshot.data!;
                  if (_tabIndex == 3) {
                    return _RecentReadsView(books: books, onOpen: _open);
                  }
                  if (_tabIndex == 2) {
                    return _BookmarksView(books: books, onOpen: _open);
                  }
                  if (_tabIndex == 1) {
                    return _AudioBooksView(
                        books: books,
                        onOpen: (book, [initialPage]) =>
                            showAudioPlayerSheet(context, book));
                  }
                  final query = _search.text.trim().toLowerCase();
                  final filtered = books.where((book) {
                    final matchesCategory =
                        _category == null || book.category == _category;
                    final matchesSearch = query.isEmpty ||
                        book.title.toLowerCase().contains(query) ||
                        book.category.toLowerCase().contains(query);
                    return matchesCategory && matchesSearch;
                  }).toList();
                  final pageCount = (filtered.length / _booksPerPage).ceil();
                  final currentPage =
                      pageCount == 0 ? 0 : _bookPage.clamp(0, pageCount - 1);
                  final pageStart = currentPage * _booksPerPage;
                  final visibleBooks = filtered
                      .skip(pageStart)
                      .take(_booksPerPage)
                      .toList(growable: false);
                  // Preserve catalogue insertion order: older categories begin on the
                  // right in this RTL list and newly added categories extend left.
                  // "Other" is always kept at the far-left end.
                  final categories = <String>[];
                  for (final book in books) {
                    if (!categories.contains(book.category)) {
                      categories.add(book.category);
                    }
                  }
                  const otherCategory = 'އެހެނިހެން';
                  if (categories.remove(otherCategory)) {
                    categories.add(otherCategory);
                  }
                  final audioBooks =
                      books.where((book) => book.hasAudio).toList();
                  final selectedTheme = CategoryTheme.forName(
                    _category ?? '',
                    dark: Theme.of(context).brightness == Brightness.dark,
                  );

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _Header(
                          bookCount: books.length,
                          darkMode: widget.darkMode,
                          onToggleTheme: widget.onToggleTheme,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: ReadingProgress(
                            bookIds: books.map((book) => book.id).toList()),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() => _bookPage = 0),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: ' ހޯދާ...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: query.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _search.clear();
                                        setState(() => _bookPage = 0);
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      if (audioBooks.isNotEmpty &&
                          query.isEmpty &&
                          _category == null)
                        SliverToBoxAdapter(
                          child: _FeaturedCarousel(
                              books: audioBooks, onOpen: _open),
                        ),
                      SliverToBoxAdapter(
                        child: _CategoryCards(
                          categories: categories,
                          books: books,
                          selected: _category,
                          onSelected: (category) => setState(() {
                            _category = _category == category ? null : category;
                            _bookPage = 0;
                          }),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _BooksSectionHeader(
                          category: _category,
                          bookCount: filtered.length,
                          theme: selectedTheme,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                        sliver: filtered.isEmpty
                            ? const SliverToBoxAdapter(child: _EmptyState())
                            : SliverGrid.builder(
                                key: ValueKey('$query-$_category-$currentPage'),
                                itemCount: visibleBooks.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: .58,
                                ),
                                itemBuilder: (context, index) => _BookTile(
                                  book: visibleBooks[index],
                                  onTap: () => _open(visibleBooks[index]),
                                ),
                              ),
                      ),
                      if (pageCount > 1)
                        SliverToBoxAdapter(
                          child: _Pagination(
                            currentPage: currentPage,
                            pageCount: pageCount,
                            color: selectedTheme.primary,
                            tint: selectedTheme.tint,
                            onSelected: (page) =>
                                setState(() => _bookPage = page),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 18)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniAudioPlayer(),
          _ModernBottomNavigation(
            selectedIndex: _tabIndex,
            onSelected: (index) => setState(() => _tabIndex = index),
          ),
        ],
      ),
    );
  }
}

class _ModernBottomNavigation extends StatelessWidget {
  const _ModernBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: AppGlass(
          radius: 25,
          tint: Theme.of(context).brightness == Brightness.dark
              ? const Color(0x551C2228)
              : const Color(0x66FFFFFF),
          child: SizedBox(
            height: 66,
            child: Row(
              children: [
                Expanded(
                  child: _NavigationItem(
                    label: 'މައި ޞަފްޙާ',
                    icon: Icons.home_rounded,
                    selected: selectedIndex == 0,
                    onTap: () => onSelected(0),
                  ),
                ),
                Expanded(
                  child: _NavigationItem(
                    label: 'އޯޑިއޯ',
                    icon: Icons.headphones_rounded,
                    selected: selectedIndex == 1,
                    onTap: () => onSelected(1),
                  ),
                ),
                Expanded(
                  child: _NavigationItem(
                    label: 'ބުކްމާކް',
                    icon: Icons.bookmarks_rounded,
                    selected: selectedIndex == 2,
                    onTap: () => onSelected(2),
                  ),
                ),
                Expanded(
                  child: _NavigationItem(
                    label: 'ފަހުން ކިޔެވުނު',
                    icon: Icons.history_rounded,
                    selected: selectedIndex == 3,
                    onTap: () => onSelected(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentReadsView extends StatelessWidget {
  const _RecentReadsView({required this.books, required this.onOpen});

  final List<Book> books;
  final void Function(Book book, [int? initialPage]) onOpen;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RecentRead>>(
      future: ProgressService.recentReads(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final booksById = {for (final book in books) book.id: book};
        final items = [
          for (final recent in snapshot.data!)
            if (booksById[recent.bookId] case final Book book)
              (book: book, recent: recent),
        ];

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: _TabHeader(
                icon: Icons.history_rounded,
                title: 'ފަހުން ކިޔެވުނު',
                subtitle: '${items.length} ފޮތް',
              ),
            ),
            if (items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _RecentReadsEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _RecentReadCard(
                      book: item.book,
                      recent: item.recent,
                      onTap: () => onOpen(item.book, item.recent.page),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecentReadCard extends StatelessWidget {
  const _RecentReadCard({
    required this.book,
    required this.recent,
    required this.onTap,
  });

  final Book book;
  final RecentRead recent;
  final VoidCallback onTap;

  String _timeLabel() {
    final elapsed = DateTime.now().difference(recent.openedAt);
    if (elapsed.inMinutes < 1) return 'މިހާރު';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} މިނިޓް ކުރިން';
    if (elapsed.inDays < 1) return '${elapsed.inHours} ގަޑިއިރު ކުރިން';
    if (elapsed.inDays == 1) return 'އިއްޔެ';
    return '${elapsed.inDays} ދުވަސް ކުރިން';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 154,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              SizedBox(width: 92, child: BookCover(book: book, compact: true)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      book.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${_timeLabel()} • ޞަފްޙާ ${recent.page}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ],
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

class _RecentReadsEmptyState extends StatelessWidget {
  const _RecentReadsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'ކިޔެވި ފޮތެއް ނެތް',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            Text(
              'ފޮތެއް ހުޅުވުމުން މިތާ ފެންނާނެ',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? (dark
                      ? Colors.white.withValues(alpha: .18)
                      : Colors.white.withValues(alpha: .65))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioBooksView extends StatefulWidget {
  const _AudioBooksView({required this.books, required this.onOpen});

  final List<Book> books;
  final void Function(Book book, [int? initialPage]) onOpen;

  @override
  State<_AudioBooksView> createState() => _AudioBooksViewState();
}

class _AudioBooksViewState extends State<_AudioBooksView> {
  static const _pageSize = 10;
  final _search = TextEditingController();
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final audioBooks = widget.books.where((book) {
      return book.hasAudio &&
          (query.isEmpty ||
              book.title.toLowerCase().contains(query) ||
              book.category.toLowerCase().contains(query));
    }).toList();
    final pageCount = (audioBooks.length / _pageSize).ceil();
    final currentPage = pageCount == 0 ? 0 : _page.clamp(0, pageCount - 1);
    final visible = audioBooks
        .skip(currentPage * _pageSize)
        .take(_pageSize)
        .toList(growable: false);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: _TabHeader(
            icon: Icons.headphones_rounded,
            title: 'އޯޑިއޯ ފޮތްތައް',
            subtitle: '${audioBooks.length} ފޮތް',
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() => _page = 0),
              decoration: InputDecoration(
                hintText: 'އޯޑިއޯ ފޮތެއް ހޯދާ...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() => _page = 0);
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
        ),
        if (visible.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _AudioBooksEmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            sliver: SliverGrid.builder(
              key: ValueKey('audio-$query-$currentPage'),
              itemCount: visible.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .58,
              ),
              itemBuilder: (context, index) => _BookTile(
                book: visible[index],
                audioOnly: true,
                detail: '${visible[index].audio.length} ބައި',
                onTap: () => widget.onOpen(visible[index]),
              ),
            ),
          ),
        if (pageCount > 1)
          SliverToBoxAdapter(
            child: _Pagination(
              currentPage: currentPage,
              pageCount: pageCount,
              color: Theme.of(context).colorScheme.primary,
              tint: Theme.of(context).colorScheme.primaryContainer,
              onSelected: (page) => setState(() => _page = page),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
      ],
    );
  }
}

class _TabHeader extends StatelessWidget {
  const _TabHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioBooksEmptyState extends StatelessWidget {
  const _AudioBooksEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.headphones_rounded,
            size: 54,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'އޯޑިއޯ ފޮތެއް ނުފެނުނު',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _BookmarksView extends StatefulWidget {
  const _BookmarksView({required this.books, required this.onOpen});

  final List<Book> books;
  final void Function(Book book, [int? initialPage]) onOpen;

  @override
  State<_BookmarksView> createState() => _BookmarksViewState();
}

class _BookmarksViewState extends State<_BookmarksView> {
  Future<void> _remove(Book book, int page) async {
    await ProgressService.removeBookmark(book.id, page);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('ޞަފްޙާ $page ގެ ބުކްމާކް ފުހެވިއްޖެ'),
        action: SnackBarAction(
          label: 'އަލުން',
          onPressed: () async {
            await ProgressService.addBookmark(book.id, page);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<int>>>(
      future: ProgressService.bookmarks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final bookmarks = snapshot.data!;
        final savedItems = <({Book book, int page})>[
          for (final book in widget.books)
            for (final page in bookmarks[book.id] ?? const <int>[])
              (book: book, page: page),
        ];

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ބުކްމާކްތައް',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${savedItems.length} ޞަފްޙާ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            if (savedItems.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _BookmarksEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
                sliver: SliverGrid.builder(
                  itemCount: savedItems.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: .58,
                  ),
                  itemBuilder: (context, index) {
                    final item = savedItems[index];
                    return _BookTile(
                      book: item.book,
                      detail: 'ޞަފްޙާ ${item.page}',
                      onTap: () => widget.onOpen(item.book, item.page),
                      onDelete: () => _remove(item.book, item.page),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BookmarksEmptyState extends StatelessWidget {
  const _BookmarksEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_add_outlined,
                size: 38,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'ބުކްމާކެއް ނެތް',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            Text(
              ' ޞަފްޙާއެއް ބުކްމާކްކުރޭ',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.bookCount,
    required this.darkMode,
    required this.onToggleTheme,
  });
  final int bookCount;
  final bool darkMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Image.asset(
              'assets/branding/app_icon.png',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'މަކްތަބާ އަޘަރިއްޔާ',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  '$bookCount ފޮތް',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          AppGlass(
            child: IconButton(
              tooltip: 'Privacy Policy',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const PrivacyPolicyScreen()),
              ),
              icon: const Icon(Icons.privacy_tip_outlined, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          AppGlass(
            child: IconButton(
              tooltip: darkMode ? 'ލައިޓް މޯޑް' : 'ޑާކް މޯޑް',
              onPressed: onToggleTheme,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Icon(
                  darkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  key: ValueKey(darkMode),
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCarousel extends StatefulWidget {
  const _FeaturedCarousel({required this.books, required this.onOpen});
  final List<Book> books;
  final ValueChanged<Book> onOpen;

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  final _controller = PageController(viewportFraction: .9);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text(
            'އަޑާއިއެކު ކިޔާ ',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 174,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.books.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, index) {
              final book = widget.books[index];
              return AnimatedPadding(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.fromLTRB(
                  0,
                  index == _page ? 0 : 8,
                  12,
                  index == _page ? 0 : 8,
                ),
                child: InkWell(
                  onTap: () => widget.onOpen(book),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.surfaceContainer,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 96, child: BookCover(book: book)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'އޯޑިއޯ ފޮތް',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                book.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: 20,
                                  height: 1.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${book.audio.length} ބައި',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 13,
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
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CategoryCards extends StatelessWidget {
  const _CategoryCards({
    required this.categories,
    required this.books,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final List<Book> books;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
          child: Text(
            'ކެޓަގަރީތައް',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final category = categories[index];
              final categoryTheme = CategoryTheme.forName(
                category,
                dark: Theme.of(context).brightness == Brightness.dark,
              );
              final count =
                  books.where((book) => book.category == category).length;
              final isSelected = selected == category;
              return AnimatedScale(
                scale: isSelected ? 1 : .97,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: InkWell(
                  onTap: () => onSelected(category),
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 164,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: categoryTheme.colors),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.secondary
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: categoryTheme.primary.withValues(alpha: .22),
                          blurRadius: isSelected ? 22 : 12,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(categoryTheme.icon,
                                color: Colors.white, size: 21),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded,
                                  color: Colors.white, size: 18),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$count ފޮތް',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .75),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BooksSectionHeader extends StatelessWidget {
  const _BooksSectionHeader({
    required this.category,
    required this.bookCount,
    required this.theme,
  });

  final String? category;
  final int bookCount;
  final CategoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 2),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 22,
            decoration: BoxDecoration(
              color: theme.primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category ?? 'ހުރިހާ ފޮތްތައް',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Text(
            '$bookCount',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.currentPage,
    required this.pageCount,
    required this.onSelected,
    required this.color,
    required this.tint,
  });

  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onSelected;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PageButton(
              icon: Icons.chevron_left_rounded,
              enabled: currentPage > 0,
              onTap: () => onSelected(currentPage - 1),
              tint: tint,
            ),
            const SizedBox(width: 8),
            ...List.generate(pageCount, (page) {
              final selected = page == currentPage;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () => onSelected(page),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: selected ? 42 : 36,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? color : tint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${page + 1}',
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 8),
            _PageButton(
              icon: Icons.chevron_right_rounded,
              enabled: currentPage < pageCount - 1,
              onTap: () => onSelected(currentPage + 1),
              tint: tint,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.tint,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: tint,
        disabledBackgroundColor: tint.withValues(alpha: .45),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.book,
    required this.onTap,
    this.detail,
    this.onDelete,
    this.audioOnly = false,
  });
  final bool audioOnly;
  final Book book;
  final VoidCallback onTap;
  final String? detail;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: book.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Align(
                      child: FractionallySizedBox(
                        widthFactor: .82,
                        heightFactor: .98,
                        child: BookCover(book: book, compact: true),
                      ),
                    ),
                    if (book.hasAudio)
                      PositionedDirectional(
                        top: 0,
                        start: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.ink.withValues(alpha: .88),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          child: Text(
                            'އޯޑިއޯ',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    if (onDelete != null)
                      PositionedDirectional(
                        top: 0,
                        end: 0,
                        child: Material(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh
                              .withValues(alpha: .96),
                          shape: const CircleBorder(),
                          elevation: 3,
                          child: IconButton(
                            tooltip: 'ބުކްމާކް ފުހެލާ',
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: Colors.redAccent,
                            iconSize: 18,
                            constraints: const BoxConstraints.tightFor(
                              width: 34,
                              height: 34,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14,
                    ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    book.hasAudio
                        ? Icons.headphones_rounded
                        : Icons.menu_book_rounded,
                    size: 13,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      detail ?? (book.hasAudio ? 'ކިޔާ • އަޑުއަހާ' : 'ކިޔާ'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 11,
                          ),
                      maxLines: 1,
                    ),
                  ),
                  if (audioOnly)
                    IconButton(
                        tooltip: 'Audio files and downloads',
                        onPressed: onTap,
                        icon: const Icon(Icons.queue_music_rounded, size: 20))
                  else
                    _BookDownloadButton(book: book),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookDownloadButton extends StatefulWidget {
  const _BookDownloadButton({required this.book});

  final Book book;

  @override
  State<_BookDownloadButton> createState() => _BookDownloadButtonState();
}

class _BookDownloadButtonState extends State<_BookDownloadButton> {
  DownloadService get _downloads => DownloadService.instance;

  @override
  void initState() {
    super.initState();
    _downloads.ensureState(widget.book);
  }

  @override
  void didUpdateWidget(covariant _BookDownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id) {
      _downloads.ensureState(widget.book);
    }
  }

  Future<void> _remove() async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ޑައުންލޯޑު ފުހެލަން؟'),
        content: const Text(
          'ފޮތާއި އޯޑިއޯތައް މި ފޯނުން ފުހެލެވޭނެ. އެކަމަކު ފޮތް ލައިބްރަރީގައި ހުންނާނެ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ނޫން'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ފުހެލާ'),
          ),
        ],
      ),
    );
    if (remove == true) {
      final handler = AudiobookAudioHandler.current;
      if (handler?.book?.id == widget.book.id) await handler!.stop();
      await _downloads.remove(widget.book);
    }
  }

  Future<void> _startOrRetry() async {
    await _downloads.download(widget.book);
    if (!mounted) return;
    if (_downloads.stateFor(widget.book.id).status ==
        BookDownloadStatus.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('ޑައުންލޯޑު ނުކުރެވުނު. އަލުން ޖައްސަވާ.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _downloads,
      builder: (context, _) {
        final state = _downloads.stateFor(widget.book.id);
        final (icon, tooltip, action) = switch (state.status) {
          BookDownloadStatus.notDownloaded => (
              Icons.download_rounded,
              'PDF ޑައުންލޯޑު',
              _startOrRetry,
            ),
          BookDownloadStatus.downloading => (
              Icons.close_rounded,
              'ހުއްޓުވާ',
              () => _downloads.cancel(widget.book.id),
            ),
          BookDownloadStatus.downloaded => (
              Icons.download_done_rounded,
              'ޑައުންލޯޑު ފުހެލާ',
              _remove,
            ),
          BookDownloadStatus.failed => (
              Icons.refresh_rounded,
              'އަލުން ޖައްސަވާ',
              _startOrRetry,
            ),
        };
        return Tooltip(
          message: tooltip,
          child: InkResponse(
            onTap: action,
            radius: 22,
            child: SizedBox.square(
              dimension: 34,
              child: state.status == BookDownloadStatus.downloading
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: state.progress,
                          strokeWidth: 2.5,
                        ),
                        if (state.progress case final double progress)
                          Text(
                            '${(progress * 100).round()}%',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else
                          Icon(icon, size: 17),
                      ],
                    )
                  : Icon(
                      icon,
                      size: 20,
                      color: state.status == BookDownloadStatus.downloaded
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
            ),
          ),
        );
      },
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 50,
              color: Color(0xFF8BA19C),
            ),
            const SizedBox(height: 12),
            Text('ފޮތެއް ނުފެނުނު',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 12),
              const Text('ފޮތްތައް ލޯޑު ނުކުރެވުނު'),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: onRetry, child: const Text('އަލުން ބަލާ')),
            ],
          ),
        ),
      );
}
