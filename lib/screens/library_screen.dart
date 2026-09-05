import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/catalog_service.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';
import '../theme/category_theme.dart';
import '../widgets/book_cover.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const _booksPerPage = 10;
  late final Future<List<Book>> _catalog = CatalogService.load();
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(book: book, initialPage: initialPage),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
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
            if (_tabIndex == 1) {
              return _BookmarksView(books: books, onOpen: _open);
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
            final categories =
                books.map((book) => book.category).toSet().toList()..sort();
            final audioBooks = books.where((book) => book.hasAudio).toList();
            final selectedTheme = CategoryTheme.forName(_category ?? '');

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Header(bookCount: books.length)),
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
                if (audioBooks.isNotEmpty && query.isEmpty && _category == null)
                  SliverToBoxAdapter(
                    child: _FeaturedCarousel(books: audioBooks, onOpen: _open),
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  sliver: filtered.isEmpty
                      ? const SliverToBoxAdapter(child: _EmptyState())
                      : SliverGrid.builder(
                          key: ValueKey('$query-$_category-$currentPage'),
                          itemCount: visibleBooks.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 16,
                            childAspectRatio: .57,
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
                      onSelected: (page) => setState(() => _bookPage = page),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 18)),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: _ModernBottomNavigation(
        selectedIndex: _tabIndex,
        onSelected: (index) => setState(() => _tabIndex = index),
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: AppTheme.outline),
            boxShadow: [
              BoxShadow(
                color: AppTheme.ink.withValues(alpha: .2),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
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
                    label: 'ބުކްމާކް',
                    icon: Icons.bookmarks_rounded,
                    selected: selectedIndex == 1,
                    onTap: () => onSelected(1),
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
              horizontal: selected ? 18 : 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: selected ? AppTheme.emerald : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.white : Colors.white60,
                  size: 23,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
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
          physics: const BouncingScrollPhysics(),
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                sliver: SliverGrid.builder(
                  itemCount: savedItems.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 16,
                    childAspectRatio: .57,
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
              decoration: const BoxDecoration(
                color: AppTheme.mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bookmark_add_outlined,
                size: 38,
                color: AppTheme.emerald,
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
  const _Header({required this.bookCount});
  final int bookCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.surfaceHigh, AppTheme.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.asset(
              'assets/branding/app_icon.png',
              width: 52,
              height: 52,
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
                  '$bookCount ފޮތް • އޮފްލައިން',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Icon(Icons.auto_stories_rounded, color: AppTheme.gold),
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
                      gradient: const LinearGradient(
                        colors: [AppTheme.mint, AppTheme.surface],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.outline),
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
                              const Text(
                                'އޯޑިއޯ ފޮތް',
                                style: TextStyle(
                                  color: AppTheme.gold,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                book.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  height: 1.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${book.audio.length} ބައި',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .7),
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
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final category = categories[index];
              final categoryTheme = CategoryTheme.forName(category);
              final count =
                  books.where((book) => book.category == category).length;
              final isSelected = selected == category;
              return AnimatedScale(
                scale: isSelected ? 1 : .96,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: InkWell(
                  onTap: () => onSelected(category),
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 210,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: categoryTheme.colors),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected ? AppTheme.gold : Colors.transparent,
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
                                color: Colors.white, size: 28),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded,
                                  color: Colors.white, size: 24),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          category,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      margin: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: theme.tint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(theme.icon, color: theme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category ?? 'ހުރިހާ ފޮތްތައް',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: theme.primary,
                  ),
            ),
          ),
          Text(
            '$bookCount',
            style: TextStyle(
              color: theme.primary,
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
  });
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
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BookCover(book: book, compact: true),
                  if (onDelete != null)
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      child: Material(
                        color: AppTheme.surfaceHigh.withValues(alpha: .96),
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: IconButton(
                          tooltip: 'ބުކްމާކް ފުހެލާ',
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: Colors.redAccent,
                          iconSize: 21,
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  book.hasAudio
                      ? Icons.headphones_rounded
                      : Icons.menu_book_rounded,
                  size: 15,
                  color: AppTheme.emerald,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    detail ?? (book.hasAudio ? 'ކިޔާ • އަޑުއަހާ' : 'ކިޔާ'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
