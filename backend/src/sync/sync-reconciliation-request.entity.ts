import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";

@Entity("sync_reconciliation_requests")
export class SyncReconciliationRequest {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ name: "tenant_id", type: "uuid" })
  tenantId: string;

  @Column({ name: "school_id", type: "uuid" })
  schoolId: string;

  @Column({ name: "campus_id", type: "uuid", nullable: true })
  campusId: string | null;

  @Column({ name: "requested_by_user_id", type: "uuid" })
  requestedByUserId: string;

  @Column({ name: "acknowledged_by_user_id", type: "uuid", nullable: true })
  acknowledgedByUserId: string | null;

  @Column({ name: "target_device_id", type: "varchar", length: 200 })
  targetDeviceId: string;

  @Column({ name: "reason", type: "varchar", length: 120 })
  reason: string;

  @Column({ name: "status", type: "varchar", length: 20, default: "pending" })
  status: "pending" | "applied";

  @Column({ name: "requested_at", type: "timestamptz" })
  requestedAt: Date;

  @Column({ name: "acknowledged_at", type: "timestamptz", nullable: true })
  acknowledgedAt: Date | null;

  @CreateDateColumn({ name: "created_at" })
  createdAt: Date;

  @UpdateDateColumn({ name: "updated_at" })
  updatedAt: Date;
}
