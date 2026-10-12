# PDF word search

Available in the Flutter Android/iOS reader and the website PDF reader.

- Text is extracted locally, one page at a time; PDFs are never changed or sent to an OCR service.
- The search icon appears only after extractable, non-whitespace text is found, even if the cover/earlier pages are scans. Image-only documents keep the existing reader without search controls.
- A mixed PDF searches its text-bearing pages. Extraction failures do not interrupt reading; search reports that results may be incomplete.
- Literal, case-insensitive words and phrases are supported, including Dhivehi/Arabic as stored in the PDF. Phrase whitespace may span lines. Search cannot repair malformed character mappings or infer text from images.
- All matches are counted and highlighted. Previous/next wraps, and a results list shows page numbers and snippets. Counts may grow while indexing continues.
- Closing the search clears highlights; closing the reader cancels indexing and releases its in-memory text index. No new backend/database setup is needed.

Checks: Flutter service tests cover scans, mixed documents, Dhivehi, repeated matches, phrases, punctuation, extraction errors and disposal. A narrow-screen widget test covers query entry, count, navigation, results and closing. Web tests cover text item offsets, matching and HTML escaping. Device/browser testing with the actual catalog PDFs is still recommended before store release, especially for older PDFs with nonstandard text encodings.
