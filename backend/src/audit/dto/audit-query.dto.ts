import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class AuditQueryDto {
  @IsOptional()
  @IsString()
  eventType?: string;

  @IsOptional()
  @IsString()
  entityType?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}
