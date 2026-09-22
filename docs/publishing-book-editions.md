# Publishing an audiobook and a reading-only edition

1. In Admin → Books, create or open the book. Set its title, category, PDF and optional cover.
2. Open the Audio tab. Add a chapter, enter its title, upload/select an audio file, and set its order. Repeat for additional chapters. A single audio file needs one chapter.
3. Enable **Publish reading-only version too · PDF**.
4. Publish the book. Saving a draft alone does not update public readers.

The updated mobile app and website show the original audiobook plus a separate `(PDF)` entry. Both reuse the same uploaded PDF, cover, category and reader-notice choice. Only the audiobook appears in the audio section. The PDF entry excludes all audio from downloads. Each edition has its own bookmarks, recent-read identity and local download folder; the existing audiobook's identity is unchanged. Downloading both editions uses a local PDF copy for each edition.

With the option off, existing behaviour remains unchanged. Books without playable audio stay a single reading entry. Disabling the option removes the extra edition from the updated catalogue; it does not erase previously downloaded files. Old mobile releases continue to show the original audiobook until updated. Cached mobile catalogues may take up to five minutes to refresh; pull to refresh to get the changes immediately.

## Deployment

The additive migration `20260923_120000_reading_edition` adds default-false fields to `books` and `_books_v`. Apply it before deploying the backend; missing columns can break the Books page. The production application status is recorded in the task's completion message. Other database environments still need the migration.

Commit and deploy the admin/web changes to Vercel. Build a new mobile release with a fresh build number through Codemagic. This feature does not require re-uploading any existing media.
