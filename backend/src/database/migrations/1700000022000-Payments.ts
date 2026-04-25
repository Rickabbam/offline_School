import { MigrationInterface, QueryRunner } from "typeorm";

export class Payments1700000022000 implements MigrationInterface {
  name = "Payments1700000022000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE payment_status AS ENUM ('draft', 'confirmed', 'posted')
    `);
    await queryRunner.query(`
      CREATE TYPE payment_mode AS ENUM ('cash', 'mtn_momo', 'telecel_cash', 'bank')
    `);
    await queryRunner.query(`
      CREATE TABLE payments (
        id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id           UUID NOT NULL,
        school_id           UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
        campus_id           UUID REFERENCES campuses(id),
        invoice_id          UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
        payment_code        VARCHAR(64) NOT NULL,
        status              payment_status NOT NULL DEFAULT 'draft',
        amount              NUMERIC(12, 2) NOT NULL,
        payment_mode        payment_mode NOT NULL,
        payment_date        DATE NOT NULL,
        reference           TEXT,
        notes               TEXT,
        received_by_user_id UUID,
        posted_at           TIMESTAMPTZ,
        sync_status         VARCHAR(50) NOT NULL DEFAULT 'synced',
        server_revision     BIGINT NOT NULL DEFAULT 0,
        deleted             BOOLEAN NOT NULL DEFAULT FALSE,
        created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(`
      CREATE INDEX idx_payments_scope_status
      ON payments(tenant_id, school_id, campus_id, invoice_id, status)
    `);
    await queryRunner.query(`
      CREATE TABLE payment_reversals (
        id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id           UUID NOT NULL,
        school_id           UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
        campus_id           UUID REFERENCES campuses(id),
        payment_id          UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
        invoice_id          UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
        amount              NUMERIC(12, 2) NOT NULL,
        reason              TEXT NOT NULL,
        reversed_by_user_id UUID,
        sync_status         VARCHAR(50) NOT NULL DEFAULT 'synced',
        server_revision     BIGINT NOT NULL DEFAULT 0,
        deleted             BOOLEAN NOT NULL DEFAULT FALSE,
        created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX uq_payment_reversals_active_payment
      ON payment_reversals(tenant_id, school_id, payment_id)
      WHERE deleted = FALSE
    `);
    await queryRunner.query(`
      CREATE INDEX idx_payment_reversals_scope_invoice
      ON payment_reversals(tenant_id, school_id, campus_id, invoice_id)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS idx_payment_reversals_scope_invoice`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS uq_payment_reversals_active_payment`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS payment_reversals`);
    await queryRunner.query(`DROP INDEX IF EXISTS idx_payments_scope_status`);
    await queryRunner.query(`DROP TABLE IF EXISTS payments`);
    await queryRunner.query(`DROP TYPE IF EXISTS payment_mode`);
    await queryRunner.query(`DROP TYPE IF EXISTS payment_status`);
  }
}
