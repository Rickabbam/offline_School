import { IsDateString, IsEnum, IsOptional, IsString, IsUUID } from 'class-validator';
import { AttendanceStatus } from '../attendance-record.entity';

export class MarkAttendanceDto {
  @IsUUID()
  studentId: string;

  @IsUUID()
  classArmId: string;

  @IsUUID()
  academicYearId: string;

  @IsUUID()
  termId: string;

  @IsDateString()
  attendanceDate: string;

  @IsOptional()
  @IsEnum(AttendanceStatus)
  status?: AttendanceStatus;

  @IsOptional()
  @IsString()
  notes?: string;
}
