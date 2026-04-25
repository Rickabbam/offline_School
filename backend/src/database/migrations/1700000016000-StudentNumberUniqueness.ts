import { MigrationInterface, QueryRunner } from "typeorm";

export class StudentNumberUniqueness1700000016000
  implements MigrationInterface
{
  name = "StudentNumberUniqueness1700000016000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      WITH ranked AS (
        SELECT
          id,
          ROW_NUMBER() OVER (
            PARTITION BY tenant_id, school_id, student_number
            ORDER BY updated_at DESC, created_at DESC, id DESC
          ) AS rn
        FROM students
        WHERE deleted = FALSE
          AND student_number IS NOT NULL
          AND student_number <> ''
      )
      UPDATE students s
      SET student_number = NULL,
          updated_at = NOW()
      FROM ranked r
      WHERE s.id = r.id
        AND r.rn > 1
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_students_student_number_active
      ON students(tenant_id, school_id, student_number)
      WHERE deleted = FALSE
        AND student_number IS NOT NULL
        AND student_number <> ''
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_students_student_number_active
    `);
  }
}
