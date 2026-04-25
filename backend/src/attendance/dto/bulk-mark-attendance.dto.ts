import { ArrayMinSize, IsArray, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { MarkAttendanceDto } from './mark-attendance.dto';

export class BulkMarkAttendanceDto {
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => MarkAttendanceDto)
  records: MarkAttendanceDto[];
}
