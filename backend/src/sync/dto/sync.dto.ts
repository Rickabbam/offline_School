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
import {
  SyncEntityType,
  SyncOperation,
  SyncPushRequestEnvelope,
  syncEntityTypes,
  syncOperations,
} from "../../../../packages/contracts/src";

export class SyncPushRequestDto implements SyncPushRequestEnvelope {
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
  @IsIn(syncOperations)
  operation: SyncOperation;

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
