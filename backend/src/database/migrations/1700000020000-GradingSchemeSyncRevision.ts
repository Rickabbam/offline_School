import { MigrationInterface, QueryRunner } from 'typeorm';

export class GradingSchemeSyncRevision1700000020000
  implements MigrationInterface
{
  name = 'GradingSchemeSyncRevision1700000020000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE SEQUENCE IF NOT EXISTS sync_server_revision_seq AS BIGINT START WITH 1
    `);
    await queryRunner.query(`
      ALTER TABLE grading_schemes
      ADD COLUMN IF NOT EXISTS server_revision BIGINT NOT NULL DEFAULT nextval('sync_server_revision_seq')
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_grading_schemes_sync_revision_scope
      ON grading_schemes(tenant_id, school_id, server_revision)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_grading_schemes_sync_revision_scope
    `);
    await queryRunner.query(`
      ALTER TABLE grading_schemes
      DROP COLUMN IF EXISTS server_revision
    `);
  }
}
