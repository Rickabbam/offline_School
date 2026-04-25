import { MigrationInterface, QueryRunner } from "typeorm";

export class SyncPushReceipts1700000004000 implements MigrationInterface {
  name = "SyncPushReceipts1700000004000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE sync_push_receipts (
        id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        idempotency_key  VARCHAR(255) NOT NULL UNIQUE,
        user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        tenant_id        UUID NOT NULL,
        school_id        UUID NOT NULL,
        campus_id        UUID,
        entity_type      VARCHAR(100) NOT NULL,
        entity_id        UUID NOT NULL,
        operation        VARCHAR(20) NOT NULL,
        response_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
        created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(`
      CREATE INDEX idx_sync_push_receipts_scope
        ON sync_push_receipts(tenant_id, school_id, entity_type)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS idx_sync_push_receipts_scope`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS sync_push_receipts`);
  }
}
