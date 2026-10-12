import 'dart:async';
import 'package:flutter/material.dart';
import '../services/pdf_search_service.dart';

class PdfSearchPanel extends StatefulWidget {
  const PdfSearchPanel(
      {super.key,
      required this.search,
      required this.current,
      required this.onSelect,
      required this.onClose});
  final PdfSearchService search;
  final int current;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;

  @override
  State<PdfSearchPanel> createState() => _PdfSearchPanelState();
}

class _PdfSearchPanelState extends State<PdfSearchPanel> {
  bool _list = false;
  Timer? _debounce;
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changeQuery(String value) {
    _debounce?.cancel();
    widget.search.search('');
    _debounce = Timer(
        const Duration(milliseconds: 250), () => widget.search.search(value));
  }

  @override
  Widget build(BuildContext context) {
    final search = widget.search;
    final matches = search.matches;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Expanded(
                  child: TextFormField(
                initialValue: search.query,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'ލަފްޒެއް ހޯދާ', border: InputBorder.none),
                onChanged: _changeQuery,
                onFieldSubmitted: (_) {
                  if (matches.isNotEmpty) widget.onSelect(0);
                },
              )),
              IconButton(
                  tooltip: 'ބަންދުކުރޭ',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close)),
            ])),
        if (search.indexing) const LinearProgressIndicator(minHeight: 2),
        Row(children: [
          IconButton(
              tooltip: 'ކުރީގެ',
              onPressed: matches.isEmpty
                  ? null
                  : () => widget.onSelect(
                      (widget.current - 1 + matches.length) % matches.length),
              icon: const Icon(Icons.keyboard_arrow_up)),
          Expanded(
              child: Text(
                  search.query.isEmpty
                      ? 'ލަފްޒެއް ލިޔުއްވާ'
                      : matches.isEmpty
                          ? (search.indexing ? 'ހޯދަނީ…' : 'ނުފެނުނު')
                          : '${widget.current + 1} / ${matches.length}',
                  textAlign: TextAlign.center)),
          IconButton(
              tooltip: 'ދެން އޮތް',
              onPressed: matches.isEmpty
                  ? null
                  : () =>
                      widget.onSelect((widget.current + 1) % matches.length),
              icon: const Icon(Icons.keyboard_arrow_down)),
          IconButton(
              tooltip: 'ނަތީޖާ',
              onPressed:
                  matches.isEmpty ? null : () => setState(() => _list = !_list),
              icon: Icon(_list ? Icons.expand_less : Icons.list)),
        ]),
        if (search.incomplete)
          const Padding(
              padding: EdgeInsets.all(8),
              child: Text('ބައެއް ޞަފްޙާތަކުން ހޯދެވުނީނުވެ.')),
        if (_list && matches.isNotEmpty)
          SizedBox(
            height: MediaQuery.sizeOf(context).height * .22,
            child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final match = matches[index];
                  final text = match.pageText.fullText;
                  final start = (match.start - 30).clamp(0, text.length);
                  final end = (match.end + 45).clamp(0, text.length);
                  return ListTile(
                      dense: true,
                      selected: index == widget.current,
                      title: Text(
                          text
                              .substring(start, end)
                              .replaceAll(RegExp(r'\s+'), ' '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text('ޞަފްޙާ ${match.pageNumber}'),
                      onTap: () {
                        setState(() => _list = false);
                        widget.onSelect(index);
                      });
                }),
          ),
      ]),
    );
  }
}
