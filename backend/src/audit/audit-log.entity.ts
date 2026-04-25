import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('audit_logs')
export class AuditLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tenant_id', type: 'uuid' })
  tenantId: string;

  @Column({ name: 'school_id', type: 'uuid' })
  schoolId: string;

  @Column({ name: 'campus_id', type: 'uuid', nullable: true })
  campusId: string | null;

  @Column({ name: 'actor_user_id', type: 'uuid', nullable: true })
  actorUserId: string | null;

  @Column({ name: 'event_type', type: 'varchar', length: 100 })
  eventType: string;

  @Column({ name: 'entity_type', type: 'varchar', length: 100 })
  entityType: string;

  @Column({ name: 'entity_id', type: 'uuid' })
  entityId: string;

  @Column({ name: 'metadata_json', type: 'jsonb', default: {} })
  metadataJson: Record<string, unknown>;

  @Column({ name: 'idempotency_key', type: 'varchar', length: 160, nullable: true })
  idempotencyKey: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
