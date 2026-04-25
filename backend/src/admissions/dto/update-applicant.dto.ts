import { IsDateString, IsEnum, IsOptional, IsString, IsUUID } from 'class-validator';
import { Gender } from '../../students/student.entity';

export class UpdateApplicantDto {
  @IsOptional()
  @IsString()
  firstName?: string;

  @IsOptional()
  @IsString()
  middleName?: string;

  @IsOptional()
  @IsString()
  lastName?: string;

  @IsOptional()
  @IsDateString()
  dateOfBirth?: string;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  @IsOptional()
  @IsUUID()
  campusId?: string;

  @IsOptional()
  @IsUUID()
  classLevelId?: string;

  @IsOptional()
  @IsUUID()
  academicYearId?: string;

  @IsOptional()
  @IsString()
  guardianName?: string;

  @IsOptional()
  @IsString()
  guardianPhone?: string;

  @IsOptional()
  @IsString()
  guardianEmail?: string;

  @IsOptional()
  @IsString()
  documentNotes?: string;
}
