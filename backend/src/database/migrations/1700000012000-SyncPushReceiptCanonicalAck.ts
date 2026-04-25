import { MigrationInterface, QueryRunner } from "typeorm";

export class SyncPushReceiptCanonicalAck1700000012000
  implements MigrationInterface
{
  name = "SyncPushReceiptCanonicalAck1700000012000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE sync_push_receipts
      ADD COLUMN IF NOT EXISTS canonical_entity_id UUID
    `);
    await queryRunner.query(`
      ALTER TABLE sync_push_receipts
      ADD COLUMN IF NOT EXISTS server_revision BIGINT
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_sync_push_receipts_canonical_entity
      ON sync_push_receipts(tenant_id, school_id, entity_type, canonical_entity_id)
      WHERE canonical_entity_id IS NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_sync_push_receipts_canonical_entity
    `);
    await queryRunner.query(`
      ALTER TABLE sync_push_receipts
      DROP COLUMN IF EXISTS server_revision
    `);
    await queryRunner.query(`
      ALTER TABLE sync_push_receipts
      DROP COLUMN IF EXISTS canonical_entity_id
    `);
  }
}
