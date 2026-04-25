import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";

@Index(
  "idx_sync_push_receipts_idempotency_scope",
  ["tenantId", "schoolId", "userId", "idempotencyKey"],
  { unique: true },
)
@Entity("sync_push_receipts")
export class SyncPushReceipt {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({
    name: "idempotency_key",
    type: "varchar",
    length: 255,
  })
  idempotencyKey: string;

  @Column({ name: "user_id", type: "uuid" })
  userId: string;

  @Column({ name: "tenant_id", type: "uuid" })
  tenantId: string;

  @Column({ name: "school_id", type: "uuid" })
  schoolId: string;

  @Column({ name: "campus_id", type: "uuid", nullable: true })
  campusId: string | null;

  @Column({ name: "origin_device_id", type: "varchar", length: 512, nullable: true })
  originDeviceId: string | null;

  @Column({ name: "lamport_clock", type: "integer", default: 0 })
  lamportClock: number;

  @Column({ name: "entity_type", type: "varchar", length: 100 })
  entityType: string;

  @Column({ name: "entity_id", type: "uuid" })
  entityId: string;

  @Column({ name: "canonical_entity_id", type: "uuid", nullable: true })
  canonicalEntityId: string | null;

  @Column({ name: "operation", type: "varchar", length: 20 })
  operation: string;

  @Column({ name: "server_revision", type: "bigint", nullable: true })
  serverRevision: number | null;

  @Column({
    name: "request_payload_hash",
    type: "varchar",
    length: 64,
    nullable: true,
  })
  requestPayloadHash: string | null;

  @Column({ name: "response_payload", type: "jsonb" })
  responsePayload: Record<string, unknown>;

  @Column({ name: "completed_at", type: "timestamptz", nullable: true })
  completedAt: Date | null;

  @CreateDateColumn({ name: "created_at" })
  createdAt: Date;

  @UpdateDateColumn({ name: "updated_at" })
  updatedAt: Date;
}
