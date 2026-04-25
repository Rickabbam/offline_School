import { MigrationInterface, QueryRunner } from "typeorm";

export class SyncReconciliationRequests1700000018000
  implements MigrationInterface
{
  name = "SyncReconciliationRequests1700000018000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "sync_reconciliation_requests" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "tenant_id" uuid NOT NULL,
        "school_id" uuid NOT NULL,
        "campus_id" uuid,
        "requested_by_user_id" uuid NOT NULL,
        "acknowledged_by_user_id" uuid,
        "target_device_id" character varying(200) NOT NULL,
        "reason" character varying(120) NOT NULL,
        "status" character varying(20) NOT NULL DEFAULT 'pending',
        "requested_at" TIMESTAMPTZ NOT NULL,
        "acknowledged_at" TIMESTAMPTZ,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        CONSTRAINT "PK_sync_reconciliation_requests_id" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "idx_sync_reconciliation_requests_pending_scope"
      ON "sync_reconciliation_requests" ("tenant_id", "school_id", "campus_id", "target_device_id", "requested_at")
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "idx_sync_reconciliation_requests_target_pending"
      ON "sync_reconciliation_requests" ("tenant_id", "school_id", "target_device_id")
      WHERE "status" = 'pending'
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX "public"."idx_sync_reconciliation_requests_target_pending"
    `);
    await queryRunner.query(`
      DROP INDEX "public"."idx_sync_reconciliation_requests_pending_scope"
    `);
    await queryRunner.query(`
      DROP TABLE "sync_reconciliation_requests"
    `);
  }
}
