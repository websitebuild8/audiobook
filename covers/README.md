# Original book covers

Add optimized cover images here using short ASCII filenames such as `dar_fitya_01.webp`.

Recommended format: WebP or JPEG, portrait orientation, approximately 800 × 1200 pixels, and ideally below 300 KB per image.

Then add `coverAsset` to the matching record in `assets/catalog.json`:

```json
{
  "id": "books/Dar Al Fitya/book_01.pdf",
  "title": "Kithab Sharia Khulasa",
  "category": "Dar Al Fitya",
  "pdfAsset": "books/Dar Al Fitya/book_01.pdf",
  "coverAsset": "covers/dar_fitya_01.webp"
}
```

If `coverAsset` is absent or the image cannot be loaded, the app automatically uses its generated cover design.
