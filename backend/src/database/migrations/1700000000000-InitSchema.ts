import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Baseline migration — establishes the schema version tracking table.
 * All subsequent feature migrations extend from this empty baseline.
 */
export class InitSchema1700000000000 implements MigrationInterface {
  name = 'InitSchema1700000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Enable UUID generation extension
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);

    // Schema version comment — actual tables are added in subsequent migrations
    await queryRunner.query(`
      COMMENT ON DATABASE "${queryRunner.connection.options.database}" IS
      'offline_School — schema baseline v1'
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Nothing to revert for the baseline marker
  }
}
