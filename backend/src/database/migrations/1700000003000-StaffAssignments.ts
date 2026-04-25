import { MigrationInterface, QueryRunner } from 'typeorm';

export class StaffAssignments1700000003000 implements MigrationInterface {
  name = 'StaffAssignments1700000003000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE staff_assignment_type AS ENUM ('class_teacher', 'subject_teacher')
    `);

    await queryRunner.query(`
      ALTER TABLE staff
      ADD COLUMN department VARCHAR(150)
    `);

    await queryRunner.query(`
      CREATE TABLE staff_teaching_assignments (
        id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id       UUID NOT NULL,
        school_id       UUID NOT NULL,
        staff_id        UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
        assignment_type staff_assignment_type NOT NULL,
        subject_id      UUID REFERENCES subjects(id) ON DELETE CASCADE,
        class_arm_id    UUID REFERENCES class_arms(id) ON DELETE CASCADE,
        deleted         BOOLEAN NOT NULL DEFAULT FALSE,
        created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    await queryRunner.query(`
      CREATE INDEX idx_staff_teaching_assignments_staff
      ON staff_teaching_assignments(staff_id)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_staff_teaching_assignments_staff
    `);
    await queryRunner.query(`DROP TABLE IF EXISTS staff_teaching_assignments`);
    await queryRunner.query(`ALTER TABLE staff DROP COLUMN IF EXISTS department`);
    await queryRunner.query(`DROP TYPE IF EXISTS staff_assignment_type`);
  }
}
