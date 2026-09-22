import { sql, type MigrateDownArgs, type MigrateUpArgs } from '@payloadcms/db-postgres'

export async function up({ db }: MigrateUpArgs): Promise<void> {
  await db.execute(sql`
    ALTER TABLE "books" ADD COLUMN IF NOT EXISTS "publish_reading_only_edition" boolean DEFAULT false;
    ALTER TABLE "_books_v" ADD COLUMN IF NOT EXISTS "version_publish_reading_only_edition" boolean DEFAULT false;
  `)
}

export async function down({ db }: MigrateDownArgs): Promise<void> {
  await db.execute(sql`
    ALTER TABLE "books" DROP COLUMN IF EXISTS "publish_reading_only_edition";
    ALTER TABLE "_books_v" DROP COLUMN IF EXISTS "version_publish_reading_only_edition";
  `)
}
