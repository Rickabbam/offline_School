import { MigrationInterface, QueryRunner } from "typeorm";

export class SyncLamportClock1700000008000 implements MigrationInterface {
  name = "SyncLamportClock1700000008000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE sync_push_receipts
      ADD COLUMN IF NOT EXISTS lamport_clock INTEGER NOT NULL DEFAULT 0
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE sync_push_receipts
      DROP COLUMN IF EXISTS lamport_clock
    `);
  }
}
