import { MigrationInterface, QueryRunner } from 'typeorm';

export class AuditLogs1700000009000 implements MigrationInterface {
  name = 'AuditLogs1700000009000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE audit_logs (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id UUID NOT NULL,
        school_id UUID NOT NULL,
        campus_id UUID,
        actor_user_id UUID,
        event_type VARCHAR(100) NOT NULL,
        entity_type VARCHAR(100) NOT NULL,
        entity_id UUID NOT NULL,
        metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(`
      CREATE INDEX idx_audit_logs_scope_event
        ON audit_logs(tenant_id, school_id, event_type, created_at)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS idx_audit_logs_scope_event`);
    await queryRunner.query(`DROP TABLE IF EXISTS audit_logs`);
  }
}
