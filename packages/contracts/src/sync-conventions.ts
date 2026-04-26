export const syncEntityTypes = [
  "student",
  "guardian",
  "enrollment",
  "fee_category",
  "fee_structure_item",
  "invoice",
  "payment",
  "payment_reversal",
  "staff",
  "applicant",
  "attendance_record",
  "academic_year",
  "term",
  "class_level",
  "class_arm",
  "subject",
  "school",
  "campus",
  "grading_scheme",
  "staff_teaching_assignment",
] as const;

export type SyncEntityType = (typeof syncEntityTypes)[number];

export const syncOperations = ["create", "update", "delete"] as const;

export type SyncOperation = (typeof syncOperations)[number];

export interface ScopedRecordEnvelope {
  id: string;
  tenantId: string;
  schoolId: string;
  campusId?: string | null;
  serverRevision: number;
  createdAt: string;
  updatedAt: string;
  deleted: boolean;
}

export interface SyncPushRequestEnvelope {
  idempotency_key: string;
  origin_device_id?: string;
  lamport_clock?: number;
  entity_type: SyncEntityType;
  entity_id: string;
  operation: SyncOperation;
  payload: Record<string, unknown>;
}

export interface SyncPushAckEnvelope {
  entityType: SyncEntityType;
  entityId: string;
  serverRevision: number;
  status: "accepted" | "replayed";
}

export interface SyncPullRecordEnvelope<TRecord extends ScopedRecordEnvelope> {
  revision: number;
  record: TRecord;
}

export interface SyncPullResponseEnvelope<TRecord extends ScopedRecordEnvelope> {
  records: Array<SyncPullRecordEnvelope<TRecord>>;
  latest_revision: number;
  next_since: number;
  has_more: boolean;
}
