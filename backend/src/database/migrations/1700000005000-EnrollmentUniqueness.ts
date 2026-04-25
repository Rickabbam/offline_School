import { MigrationInterface, QueryRunner } from "typeorm";

export class EnrollmentUniqueness1700000005000
  implements MigrationInterface
{
  name = "EnrollmentUniqueness1700000005000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DELETE FROM enrollments older
      USING enrollments newer
      WHERE older.id <> newer.id
        AND older.deleted = FALSE
        AND newer.deleted = FALSE
        AND older.tenant_id = newer.tenant_id
        AND older.school_id = newer.school_id
        AND older.student_id = newer.student_id
        AND older.academic_year_id = newer.academic_year_id
        AND (
          older.updated_at < newer.updated_at OR
          (older.updated_at = newer.updated_at AND older.created_at < newer.created_at) OR
          (older.updated_at = newer.updated_at AND older.created_at = newer.created_at AND older.id < newer.id)
        )
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_enrollments_student_year_active
        ON enrollments(tenant_id, school_id, student_id, academic_year_id)
        WHERE deleted = FALSE
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_enrollments_student_year_active
    `);
  }
}
