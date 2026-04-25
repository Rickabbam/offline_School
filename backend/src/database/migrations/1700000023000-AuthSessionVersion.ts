import { MigrationInterface, QueryRunner } from 'typeorm';

export class AuthSessionVersion1700000023000 implements MigrationInterface {
  name = 'AuthSessionVersion1700000023000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE users
      ADD COLUMN IF NOT EXISTS session_version INTEGER NOT NULL DEFAULT 1
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE users
      DROP COLUMN IF EXISTS session_version
    `);
  }
}
