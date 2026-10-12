import { sql, type MigrateDownArgs, type MigrateUpArgs } from '@payloadcms/db-postgres'

export async function up({ db }: MigrateUpArgs): Promise<void> {
  await db.execute(sql`
    CREATE TABLE IF NOT EXISTS push_registration_limits (key varchar PRIMARY KEY, window_id bigint NOT NULL, attempts integer NOT NULL);
    CREATE TABLE IF NOT EXISTS notifications (
      id serial PRIMARY KEY,
      title varchar NOT NULL,
      message varchar NOT NULL,
      status varchar DEFAULT 'draft',
      sent_at timestamp(3) with time zone,
      provider_message_id varchar,
      sent_by varchar,
      delivery_note varchar,
      updated_at timestamp(3) with time zone DEFAULT now() NOT NULL,
      created_at timestamp(3) with time zone DEFAULT now() NOT NULL
    );
    CREATE INDEX IF NOT EXISTS notifications_updated_at_idx ON notifications(updated_at);
    CREATE INDEX IF NOT EXISTS notifications_created_at_idx ON notifications(created_at);
    ALTER TABLE payload_locked_documents_rels ADD COLUMN IF NOT EXISTS notifications_id integer REFERENCES notifications(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS payload_locked_documents_rels_notifications_id_idx ON payload_locked_documents_rels(notifications_id);
  `)
}
export async function down({ db }: MigrateDownArgs): Promise<void> {
  await db.execute(sql`
    ALTER TABLE payload_locked_documents_rels DROP COLUMN IF EXISTS notifications_id;
    DROP TABLE IF EXISTS notifications;
    DROP TABLE IF EXISTS push_registration_limits;
  `)
}
