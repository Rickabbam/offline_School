import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";

export enum FeeBillingTerm {
  PerTerm = "per_term",
  OneTime = "one_time",
}

export enum InvoiceStatus {
  Draft = "draft",
  Confirmed = "confirmed",
  Posted = "posted",
}

export enum PaymentStatus {
  Draft = "draft",
  Confirmed = "confirmed",
  Posted = "posted",
}

export enum PaymentMode {
  Cash = "cash",
  MtnMoMo = "mtn_momo",
  TelecelCash = "telecel_cash",
  Bank = "bank",
}

@Entity("fee_categories")
export class FeeCategory {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ name: "tenant_id", type: "uuid" })
  tenantId: string;

  @Column({ name: "school_id", type: "uuid" })
  schoolId: string;

  @Column({ type: "varchar", length: 150 })
  name: string;

  @Column({
    name: "billing_term",
    type: "varchar",
    length: 20,
    default: FeeBillingTerm.PerTerm,
  })
  billingTerm: FeeBillingTerm;

  @Column({ name: "is_active", type: "boolean", default: true })
  isActive: boolean;

  @Column({ name: "server_revision", type: "bigint", default: 0 })
  serverRevision: number;

  @Column({ name: "deleted", type: "boolean", default: false })
  deleted: boolean;

  @CreateDateColumn({ name: "created_at" })
  createdAt: Date;

  @UpdateDateColumn({ name: "updated_at" })
  updatedAt: Date;
}

@Entity("fee_structure_items")
export class FeeStructureItem {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ name: "tenant_id", type: "uuid" })
  tenantId: string;

  @Column({ name: "school_id", type: "uuid" })
  schoolId: string;

  @Column({ name: "fee_category_id", type: "uuid" })
  feeCategoryId: string;

  @Column({ name: "class_level_id", type: "uuid", nullable: true })
  classLevelId: string | null;

  @Column({ name: "term_id", type: "uuid", nullable: true })
  termId: string | null;

  @Column({ type: "numeric", precision: 12, scale: 2 })
  amount: string;

  @Column({ type: "text", nullable: true })
  notes: string | null;

  @Column({ name: "server_revision", type: "bigint", default: 0 })
  serverRevision: number;

  @Column({ name: "deleted", type: "boolean", default: false })
  deleted: boolean;

  @CreateDateColumn({ name: "created_at" })
  createdAt: Date;

  @UpdateDateColumn({ name: "updated_at" })
  updatedAt: Date;
}

@Entity("invoices")
export class Invoice {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ name: "tenant_id", type: "uuid" })
  tenantId: string;

  @Column({ name: "school_id", type: "uuid" })
  schoolId: string;

  @Column({ name: "campus_id", type: "uuid", nullable: true })
  campusId: string | null;

  @Column({ name: "student_id", type: "uuid" })
  studentId: string;

  @Column({ name: "academic_year_id", type: "uuid" })
  academicYearId: string;

  @Column({ name: "term_id", type: "uuid" })
  termId: string;

  @Column({ name: "class_arm_id", type: "uuid" })
  classArmId: string;

  @Column({ name: "invoice_code", type: "varchar", length: 64 })
  invoiceCode: string;

  @Column({
    type: "enum",
    enum: InvoiceStatus,
    default: InvoiceStatus.Draft,
  })
  status: InvoiceStatus;

  @Column({ name: "line_items", type: "jsonb", default: () => "'[]'" })
  lineItems: object;

  @Column({ name: "total_amount", type: "numeric", precision: 12, scale: 2 })
  totalAmount: string;

  @Column({ name: "generated_by_user_id", type: "uuid", nullable: true })
  generatedByUserId: string | null;

  @Column({ name: "posted_at", type: "timestamptz", nullable: true })
  postedAt: Date | null;

  @Column({
    name: "sync_status",
    type: "varchar",
    length: 50,
    default: "synced",
  })
  syncStatus: string;

  @Column({ name: "server_revision", type: "bigint", default: 0 })
  serverRevision: number;

  @Column({ name: "deleted", type: "boolean", default: false })
  deleted: boolean;

  @CreateDateColumn({ name: "created_at" })
  createdAt: Date;

  @UpdateDateColumn({ name: "updated_at" })
  updatedAt: Date;
}

@Entity("payments")
export class Payment {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ name: "tenant_id", type: "uuid" })
  tenantId: string;

  @Column({ name: "school_id", type: "uuid" })
  schoolId: string;

  @Column({ name: "campus_id", type: "uuid", nullable: true })
  campusId: string | null;

  @Column({ name: "invoice_id", type: "uuid" })
  invoiceId: string;

  @Column({ name: "payment_code", type: "varchar", length: 64 })
  paymentCode: string;

  @Column({
    type: "enum",
    enum: PaymentStatus,
    default: PaymentStatus.Draft,
  })
  status: PaymentStatus;

  @Column({ type: "numeric", precision: 12, scale: 2 })
  amount: string;

  @Column({
    name: "payment_mode",
    type: "enum",
    enum: PaymentMode,
  })
  paymentMode: PaymentMode;

  @Column({ name: "payment_date", type: "date" })
  paymentDate: string;

  @Column({ type: "text", nullable: true })
  reference: string | null;

  @Column({ type: "text", nullable: true })
  notes: string | null;

  @Column({ name: "received_by_user_id", type: "uuid", nullable: true })
  receivedByUserId: string | null;

  @Column({ name: "posted_at", type: "timestamptz", nullable: true })
  postedAt: Date | null;

  @Column({
    name: "sync_status",
    type: "varchar",
    length: 50,
    default: "synced",
  })
  syncStatus: string;

  @Column({ name: "server_revision", type: "bigint", default: 0 })
  serverRevision: number;

  @Column({ name: "deleted", type: "boolean", default: false })
  deleted: boolean;

  @CreateDateColumn({ name: "created_at" })
  createdAt: Date;

  @UpdateDateColumn({ name: "updated_at" })
  updatedAt: Date;
}

@Entity("payment_reversals")
export class PaymentReversal {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ name: "tenant_id", type: "uuid" })
  tenantId: string;

  @Column({ name: "school_id", type: "uuid" })
  schoolId: string;

  @Column({ name: "campus_id", type: "uuid", nullable: true })
  campusId: string | null;

  @Column({ name: "payment_id", type: "uuid" })
  paymentId: string;

  @Column({ name: "invoice_id", type: "uuid" })
  invoiceId: string;

  @Column({ type: "numeric", precision: 12, scale: 2 })
  amount: string;

  @Column({ type: "text" })
  reason: string;

  @Column({ name: "reversed_by_user_id", type: "uuid", nullable: true })
  reversedByUserId: string | null;

  @Column({
    name: "sync_status",
    type: "varchar",
    length: 50,
    default: "synced",
  })
  syncStatus: string;

  @Column({ name: "server_revision", type: "bigint", default: 0 })
  serverRevision: number;

  @Column({ name: "deleted", type: "boolean", default: false })
  deleted: boolean;

  @CreateDateColumn({ name: "created_at" })
  createdAt: Date;

  @UpdateDateColumn({ name: "updated_at" })
  updatedAt: Date;
}
