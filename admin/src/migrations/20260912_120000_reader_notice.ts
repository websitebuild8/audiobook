import { sql, type MigrateDownArgs, type MigrateUpArgs } from '@payloadcms/db-postgres'

// Add the opt-in flag to both saved books and Payload's draft/version snapshots.
export async function up({ db }: MigrateUpArgs): Promise<void> {
  await db.execute(sql`
    ALTER TABLE "books" ADD COLUMN IF NOT EXISTS "show_reader_notice" boolean DEFAULT false;
    ALTER TABLE "_books_v" ADD COLUMN IF NOT EXISTS "version_show_reader_notice" boolean DEFAULT false;
  `)
}

export async function down({ db }: MigrateDownArgs): Promise<void> {
  await db.execute(sql`
    ALTER TABLE "books" DROP COLUMN IF EXISTS "show_reader_notice";
    ALTER TABLE "_books_v" DROP COLUMN IF EXISTS "version_show_reader_notice";
  `)
}
