import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from "typeorm";
import { Tenant } from "../tenants/tenant.entity";

export enum SchoolType {
  Basic = "basic",
  JHS = "jhs",
  SHS = "shs",
  Combined = "combined",
}

@Entity("schools")
export class School {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ name: "tenant_id", type: "uuid" })
  tenantId: string;

  @ManyToOne(() => Tenant, { onDelete: "CASCADE" })
  @JoinColumn({ name: "tenant_id" })
  tenant: Tenant;

  @Column({ type: "varchar", length: 255 })
  name: string;

  @Column({ name: "short_name", type: "varchar", length: 100, nullable: true })
  shortName: string | null;

  @Column({
    name: "school_type",
    type: "enum",
    enum: SchoolType,
    default: SchoolType.Basic,
  })
  schoolType: SchoolType;

  @Column({ type: "varchar", length: 255, nullable: true })
  address: string | null;

  @Column({ type: "varchar", length: 50, nullable: true })
  region: string | null;

  @Column({ type: "varchar", length: 50, nullable: true })
  district: string | null;

  @Column({
    name: "contact_phone",
    type: "varchar",
    length: 50,
    nullable: true,
  })
  contactPhone: string | null;

  @Column({
    name: "contact_email",
    type: "varchar",
    length: 255,
    nullable: true,
  })
  contactEmail: string | null;

  @Column({
    name: "onboarding_defaults",
    type: "jsonb",
    default: () => "'{}'",
  })
  onboardingDefaults: Record<string, unknown>;

  @Column({ name: "deleted", type: "boolean", default: false })
  deleted: boolean;

  @Column({ name: "server_revision", type: "bigint", default: 0 })
  serverRevision: number;

  @CreateDateColumn({ name: "created_at" })
  createdAt: Date;

  @UpdateDateColumn({ name: "updated_at" })
  updatedAt: Date;
}
