import { MigrationInterface, QueryRunner } from 'typeorm';

const workspaceRevisionTables = ['schools', 'campuses'];

export class WorkspaceSyncRevision1700000021000
  implements MigrationInterface
{
  name = 'WorkspaceSyncRevision1700000021000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE SEQUENCE IF NOT EXISTS sync_server_revision_seq AS BIGINT START WITH 1
    `);

    for (const table of workspaceRevisionTables) {
      await queryRunner.query(`
        ALTER TABLE ${table}
        ADD COLUMN IF NOT EXISTS server_revision BIGINT NOT NULL DEFAULT nextval('sync_server_revision_seq')
      `);
      await queryRunner.query(`
        CREATE INDEX IF NOT EXISTS idx_${table}_sync_revision_scope
        ON ${table}(tenant_id, server_revision)
      `);
    }
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    for (const table of [...workspaceRevisionTables].reverse()) {
      await queryRunner.query(`
        DROP INDEX IF EXISTS idx_${table}_sync_revision_scope
      `);
      await queryRunner.query(`
        ALTER TABLE ${table}
        DROP COLUMN IF EXISTS server_revision
      `);
    }
  }
}
