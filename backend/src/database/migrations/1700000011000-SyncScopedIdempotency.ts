import { MigrationInterface, QueryRunner } from "typeorm";

export class SyncScopedIdempotency1700000011000
  implements MigrationInterface
{
  name = "SyncScopedIdempotency1700000011000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE sync_push_receipts
      ADD COLUMN IF NOT EXISTS request_payload_hash VARCHAR(64)
    `);
    await queryRunner.query(`
      ALTER TABLE sync_push_receipts
      DROP CONSTRAINT IF EXISTS sync_push_receipts_idempotency_key_key
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_push_receipts_idempotency_scope
      ON sync_push_receipts(tenant_id, school_id, user_id, idempotency_key)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_sync_push_receipts_idempotency_scope
    `);
    await queryRunner.query(`
      ALTER TABLE sync_push_receipts
      ADD CONSTRAINT sync_push_receipts_idempotency_key_key UNIQUE (idempotency_key)
    `);
    await queryRunner.query(`
      ALTER TABLE sync_push_receipts
      DROP COLUMN IF EXISTS request_payload_hash
    `);
  }
}
