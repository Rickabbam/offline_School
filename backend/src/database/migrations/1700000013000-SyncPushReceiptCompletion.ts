import { MigrationInterface, QueryRunner } from "typeorm";

export class SyncPushReceiptCompletion1700000013000
  implements MigrationInterface
{
  name = "SyncPushReceiptCompletion1700000013000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE sync_push_receipts
      ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_sync_push_receipts_completed
      ON sync_push_receipts(tenant_id, school_id, completed_at)
      WHERE completed_at IS NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_sync_push_receipts_completed
    `);
    await queryRunner.query(`
      ALTER TABLE sync_push_receipts
      DROP COLUMN IF EXISTS completed_at
    `);
  }
}
