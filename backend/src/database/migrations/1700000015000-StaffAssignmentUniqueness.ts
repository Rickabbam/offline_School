import { MigrationInterface, QueryRunner } from "typeorm";

export class StaffAssignmentUniqueness1700000015000
  implements MigrationInterface
{
  name = "StaffAssignmentUniqueness1700000015000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DELETE FROM staff_teaching_assignments older
      USING staff_teaching_assignments newer
      WHERE older.id <> newer.id
        AND older.deleted = FALSE
        AND newer.deleted = FALSE
        AND older.tenant_id = newer.tenant_id
        AND older.school_id = newer.school_id
        AND older.staff_id = newer.staff_id
        AND older.assignment_type = newer.assignment_type
        AND COALESCE(older.subject_id::text, 'null') = COALESCE(newer.subject_id::text, 'null')
        AND COALESCE(older.class_arm_id::text, 'null') = COALESCE(newer.class_arm_id::text, 'null')
        AND (
          older.updated_at < newer.updated_at OR
          (older.updated_at = newer.updated_at AND older.created_at < newer.created_at) OR
          (older.updated_at = newer.updated_at AND older.created_at = newer.created_at AND older.id < newer.id)
        )
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_assignment_unique_class_teacher_active
      ON staff_teaching_assignments(tenant_id, school_id, staff_id, class_arm_id)
      WHERE deleted = FALSE
        AND assignment_type = 'class_teacher'
        AND class_arm_id IS NOT NULL
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_assignment_unique_subject_teacher_active
      ON staff_teaching_assignments(tenant_id, school_id, staff_id, subject_id)
      WHERE deleted = FALSE
        AND assignment_type = 'subject_teacher'
        AND subject_id IS NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_staff_assignment_unique_subject_teacher_active
    `);
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_staff_assignment_unique_class_teacher_active
    `);
  }
}
