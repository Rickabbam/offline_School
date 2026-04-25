import { MigrationInterface, QueryRunner } from "typeorm";

export class Invoices1700000020000 implements MigrationInterface {
  name = "Invoices1700000020000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE invoice_status AS ENUM ('draft', 'confirmed', 'posted')
    `);
    await queryRunner.query(`
      CREATE TABLE invoices (
        id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id            UUID NOT NULL,
        school_id            UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
        campus_id            UUID,
        student_id           UUID NOT NULL REFERENCES students(id),
        academic_year_id     UUID NOT NULL REFERENCES academic_years(id),
        term_id              UUID NOT NULL REFERENCES terms(id),
        class_arm_id         UUID NOT NULL REFERENCES class_arms(id),
        invoice_code         VARCHAR(64) NOT NULL,
        status               invoice_status NOT NULL DEFAULT 'draft',
        line_items           JSONB NOT NULL DEFAULT '[]',
        total_amount         NUMERIC(12, 2) NOT NULL,
        generated_by_user_id UUID,
        posted_at            TIMESTAMPTZ,
        sync_status          VARCHAR(50) NOT NULL DEFAULT 'synced',
        server_revision      BIGINT NOT NULL DEFAULT 0,
        deleted              BOOLEAN NOT NULL DEFAULT FALSE,
        created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX uq_invoices_active_student_term
      ON invoices(tenant_id, school_id, student_id, term_id)
      WHERE deleted = FALSE
    `);
    await queryRunner.query(`
      CREATE INDEX idx_invoices_scope_status
      ON invoices(tenant_id, school_id, campus_id, status, term_id)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS idx_invoices_scope_status`);
    await queryRunner.query(`DROP INDEX IF EXISTS uq_invoices_active_student_term`);
    await queryRunner.query(`DROP TABLE IF EXISTS invoices`);
    await queryRunner.query(`DROP TYPE IF EXISTS invoice_status`);
  }
}
