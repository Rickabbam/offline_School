import { IsDateString, IsOptional, IsUUID } from "class-validator";

export class EnrollApplicantDto {
  @IsUUID()
  classArmId: string;

  @IsUUID()
  @IsOptional()
  academicYearId?: string;

  @IsDateString()
  @IsOptional()
  enrollmentDate?: string;
}
