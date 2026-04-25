import { MigrationInterface, QueryRunner } from "typeorm";

export class FeeStructures1700000019000 implements MigrationInterface {
  name = "FeeStructures1700000019000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE fee_categories (
        id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id       UUID NOT NULL,
        school_id       UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
        name            VARCHAR(150) NOT NULL,
        billing_term    VARCHAR(20) NOT NULL DEFAULT 'per_term',
        is_active       BOOLEAN NOT NULL DEFAULT TRUE,
        server_revision BIGINT NOT NULL DEFAULT 0,
        deleted         BOOLEAN NOT NULL DEFAULT FALSE,
        created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(`
      CREATE INDEX idx_fee_categories_school
      ON fee_categories(tenant_id, school_id, deleted, name)
    `);
    await queryRunner.query(`
      CREATE TABLE fee_structure_items (
        id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id       UUID NOT NULL,
        school_id       UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
        fee_category_id UUID NOT NULL REFERENCES fee_categories(id) ON DELETE CASCADE,
        class_level_id  UUID REFERENCES class_levels(id),
        term_id         UUID REFERENCES terms(id),
        amount          NUMERIC(12, 2) NOT NULL,
        notes           TEXT,
        server_revision BIGINT NOT NULL DEFAULT 0,
        deleted         BOOLEAN NOT NULL DEFAULT FALSE,
        created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(`
      CREATE INDEX idx_fee_structure_items_scope
      ON fee_structure_items(
        tenant_id,
        school_id,
        fee_category_id,
        COALESCE(class_level_id, '00000000-0000-0000-0000-000000000000'::uuid),
        COALESCE(term_id, '00000000-0000-0000-0000-000000000000'::uuid)
      )
      WHERE deleted = FALSE
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS idx_fee_structure_items_scope`);
    await queryRunner.query(`DROP TABLE IF EXISTS fee_structure_items`);
    await queryRunner.query(`DROP INDEX IF EXISTS idx_fee_categories_school`);
    await queryRunner.query(`DROP TABLE IF EXISTS fee_categories`);
  }
}
