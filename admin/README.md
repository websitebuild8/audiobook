# Makthaba Athariyya Idhaaraa

Dhivehi-first RTL administration dashboard and API for the Flutter reader.

## Included

- Administrator login and roles
- Categories with ordering and visibility
- Books with cover, PDF, author, description, featured state, drafts, and publishing
- Ordered audio chapters on each book
- Local uploads during development and optional Cloudflare R2 in production
- Public read-only REST API; all write operations require authentication
- Dhivehi labels, Faseyha font support, RTL layout, and branded dashboard

## Start locally

1. Use Node.js 20.9 or newer and PostgreSQL, or create a free Neon database.
2. Copy `.env.example` to `.env` and fill in `DATABASE_URI` and `PAYLOAD_SECRET`.
3. Copy `../fonts/Faseyha_reg_hinted_v2.ttf` to `public/fonts/Faseyha.ttf`.
4. Run `npm install`, followed by `npm run dev`.
5. Open `http://localhost:3000/admin` and create the first administrator.

If the R2 variables are empty, uploaded files are stored in `admin/media` locally. Configure every S3 variable before production so PDFs and audio survive deployments.

## Flutter API

Published books are available from:

```text
GET /api/books?where[status][equals]=published&depth=2&limit=10&page=1&sort=order
```

Categories are available from:

```text
GET /api/categories?where[active][equals]=true&limit=100&sort=order
```

The Flutter integration should be added after this dashboard is running at a stable public URL. Until then, the existing bundled catalogue continues to work unchanged.

## Deploying to Vercel

1. Import the GitHub repository and set the Vercel **Root Directory** to `admin`.
2. Keep the framework preset as **Next.js** and the build command as `npm run build`.
3. Add every value from `.env.example` in Vercel Project Settings > Environment Variables.
4. Set `NEXT_PUBLIC_SERVER_URL` to the final Vercel URL, such as `https://your-project.vercel.app`.
5. Add that same URL to the R2 CORS `AllowedOrigins` list while retaining `http://localhost:3000` for local development.

Media URLs point directly to the public R2 domain, so PDFs and audio do not pass through Vercel functions.

## Admin overview

The admin dashboard includes collection shortcuts, book/category/audio totals, category
and file-format charts, recent edits, and recorded media sizes. It uses the existing
Payload REST API with the current admin session and follows all pages with selected
fields at depth zero. Authentication is checked before and after each snapshot;
failed requests show an error instead of incomplete totals. Refresh keeps a clearly
labelled previous snapshot if the new request fails.

Audio coverage counts books with at least one attached audio chapter, not chapter count.
PDF coverage uses the PDF relationship. Each book belongs to exactly one format group.
Media size is the sum of known original-upload `filesize` values; missing sizes are
identified. It is not total R2 bucket usage and excludes derivatives, quotas, and
listening/download statistics. There are no fabricated production metrics.

Dhivehi titles, Faseyha typography, RTL navigation, the supplied Makthaba logo, Payload
collection editors, theme selection, and the separate public frontend are retained.
Dashboard analytics labels are in English alongside Dhivehi navigation. Styles stay
inside the existing Payload stylesheet rather than loading Tailwind's global reset
into Payload's forms. No database schema or storage configuration changes are needed.

Validation commands (Node 20.9+):

```sh
npm run generate:importmap
npx tsc --noEmit
npx tsx --test src/components/dashboard/analytics.test.ts
npm run build
```

Before deploying, verify login/logout, create/edit/publish a book, category editing,
and PDF/audio uploads using the configured Neon/R2 environment. This worktree has no
local database credentials; visual verification used isolated test responses, not
production metrics. Desktop (1440px) and mobile (390px), dark mode, loading, empty,
error, and retry recovery were checked. No deployment or push was performed.

Files changed for this redesign:

- `src/components/Welcome.tsx`: overview UI, refresh, loading and error states.
- `src/components/dashboard/analytics.ts`: paginated reads, session checks, analytics.
- `src/components/dashboard/analytics.test.ts`: four passing analytics and data-loading tests.
- `src/components/AdminNavLinks.tsx`: public-library navigation shortcut.
- `src/components/Logo.tsx`: supplied Makthaba identity in Payload branding.
- `src/app/(payload)/custom.scss`: responsive dashboard and admin styling.
- `src/collections/Books.ts`: correct the default list columns to match the schema.
- `src/payload.config.ts` and `src/app/(payload)/admin/importMap.js`: register navigation component.
- `next-env.d.ts`: Next.js-generated production type references.
- `README.md`: analytics definitions, validation, and deployment handoff.

Final verification: TypeScript passed; all four analytics tests passed; production
build completed successfully; browser checks passed without page errors or horizontal
overflow at the tested viewport sizes. Live authenticated CRUD and R2 uploads remain
to be checked with configured services. The frontend changes require no migrations.
