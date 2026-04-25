import { Type } from "class-transformer";
import {
  IsNotEmpty,
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from "class-validator";

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

export class SyncPushRequestDto {
  @IsString()
  idempotency_key: string;

  @IsOptional()
  @IsString()
  origin_device_id?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  lamport_clock?: number;

  @IsString()
  @IsIn(syncEntityTypes)
  entity_type: SyncEntityType;

  @IsString()
  entity_id: string;

  @IsString()
  @IsIn(["create", "update", "delete"])
  operation: "create" | "update" | "delete";

  @IsObject()
  payload: Record<string, unknown>;
}

export class SyncPullQueryDto {
  @IsString()
  @IsIn(syncEntityTypes)
  entity_type: SyncEntityType;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  since: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number;
}

export class SyncReconciliationRequestDto {
  @IsString()
  @IsNotEmpty()
  target_device_id: string;

  @IsOptional()
  @IsString()
  campus_id?: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  reason?: string;
}

export class SyncReconciliationCurrentQueryDto {
  @IsString()
  @IsNotEmpty()
  device_id: string;
}

export class SyncReconciliationAckDto {
  @IsString()
  @IsNotEmpty()
  device_id: string;
}
