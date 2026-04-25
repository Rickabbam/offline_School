import { IsIn, IsObject, IsOptional, IsString, Length } from 'class-validator';

export const operatorAuditEventTypes = [
  'backup_created',
  'backup_export_encrypted',
  'restore_package_staged',
  'restore_apply_requested',
  'restore_reconciliation_completed',
  'restore_drill_passed',
  'restore_drill_failed',
  'sync_conflict_ignored',
  'sync_conflict_requeued',
] as const;

export class OperatorAuditEventDto {
  @IsIn(operatorAuditEventTypes)
  eventType: (typeof operatorAuditEventTypes)[number];

  @IsString()
  @Length(16, 160)
  idempotencyKey: string;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}
