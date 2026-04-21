import { IsString, IsOptional, IsEnum, IsDateString } from 'class-validator';
import { StudentStatus, Gender } from '../student.entity';

export class CreateStudentDto {
  @IsString()
  firstName: string;

  @IsString()
  @IsOptional()
  middleName?: string;

  @IsString()
  lastName: string;

  @IsOptional()
  @IsDateString()
  dateOfBirth?: string;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  @IsOptional()
  @IsString()
  studentNumber?: string;

  @IsOptional()
  @IsString()
  campusId?: string;
}
