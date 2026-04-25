import { MigrationInterface, QueryRunner } from "typeorm";

export class SyncOriginDevice1700000007000 implements MigrationInterface {
  name = "SyncOriginDevice1700000007000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE sync_push_receipts
      ADD COLUMN IF NOT EXISTS origin_device_id VARCHAR(512)
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_sync_push_receipts_origin_device
        ON sync_push_receipts(origin_device_id)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS idx_sync_push_receipts_origin_device`,
    );
    await queryRunner.query(`
      ALTER TABLE sync_push_receipts
      DROP COLUMN IF EXISTS origin_device_id
    `);
  }
}
