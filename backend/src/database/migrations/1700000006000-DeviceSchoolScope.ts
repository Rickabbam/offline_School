import { MigrationInterface, QueryRunner } from 'typeorm';

export class DeviceSchoolScope1700000006000 implements MigrationInterface {
  name = 'DeviceSchoolScope1700000006000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE devices
      ADD COLUMN IF NOT EXISTS school_id UUID
    `);

    await queryRunner.query(`
      UPDATE devices
      SET school_id = users.school_id
      FROM users
      WHERE users.id = devices.registered_by_user_id
        AND devices.school_id IS NULL
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_devices_school_scope
        ON devices(tenant_id, school_id, campus_id)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_devices_school_scope
    `);
    await queryRunner.query(`
      ALTER TABLE devices
      DROP COLUMN IF EXISTS school_id
    `);
  }
}
