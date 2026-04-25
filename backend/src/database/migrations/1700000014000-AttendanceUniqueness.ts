import { MigrationInterface, QueryRunner } from "typeorm";

export class AttendanceUniqueness1700000014000
  implements MigrationInterface
{
  name = "AttendanceUniqueness1700000014000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DELETE FROM attendance_records older
      USING attendance_records newer
      WHERE older.id <> newer.id
        AND older.deleted = FALSE
        AND newer.deleted = FALSE
        AND older.tenant_id = newer.tenant_id
        AND older.school_id = newer.school_id
        AND older.student_id = newer.student_id
        AND older.class_arm_id = newer.class_arm_id
        AND older.attendance_date = newer.attendance_date
        AND (
          older.updated_at < newer.updated_at OR
          (older.updated_at = newer.updated_at AND older.created_at < newer.created_at) OR
          (older.updated_at = newer.updated_at AND older.created_at = newer.created_at AND older.id < newer.id)
        )
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_student_class_date_active
      ON attendance_records(tenant_id, school_id, student_id, class_arm_id, attendance_date)
      WHERE deleted = FALSE
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_attendance_student_class_date_active
    `);
  }
}
