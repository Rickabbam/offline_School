import { MigrationInterface, QueryRunner } from 'typeorm';

export class AuditOperatorIdempotency1700000017000
  implements MigrationInterface
{
  name = 'AuditOperatorIdempotency1700000017000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "audit_logs"
      ADD COLUMN "idempotency_key" character varying(160)
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "idx_audit_logs_scope_idempotency"
      ON "audit_logs" ("tenant_id", "school_id", "idempotency_key")
      WHERE "idempotency_key" IS NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX "public"."idx_audit_logs_scope_idempotency"
    `);
    await queryRunner.query(`
      ALTER TABLE "audit_logs"
      DROP COLUMN "idempotency_key"
    `);
  }
}
