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
