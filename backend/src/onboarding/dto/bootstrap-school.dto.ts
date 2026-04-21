import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsEmail,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { SchoolType } from '../../schools/school.entity';

export class BootstrapTermDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  name: string;

  @IsInt()
  @Min(1)
  @Max(3)
  termNumber: number;

  @IsDateString()
  startDate: string;

  @IsDateString()
  endDate: string;

  @IsBoolean()
  isCurrent: boolean;
}

export class BootstrapAcademicYearDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  label: string;

  @IsDateString()
  startDate: string;

  @IsDateString()
  endDate: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BootstrapTermDto)
  terms: BootstrapTermDto[];
}

export class BootstrapCampusDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  address?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  contactPhone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  registrationCode?: string;
}

export class BootstrapSchoolProfileDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  shortName?: string;

  @IsEnum(SchoolType)
  schoolType: SchoolType;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  address?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  region?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  district?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  contactPhone?: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(255)
  contactEmail?: string;
}

export class BootstrapClassArmDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  arm: string;
}

export class BootstrapClassLevelDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  name: string;

  @IsInt()
  @Min(0)
  sortOrder: number;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BootstrapClassArmDto)
  arms: BootstrapClassArmDto[];
}

export class BootstrapSubjectDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(150)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  code?: string;
}

export class BootstrapGradingBandDto {
  @IsString()
  @IsNotEmpty()
  grade: string;

  @IsInt()
  @Min(0)
  @Max(100)
  min: number;

  @IsInt()
  @Min(0)
  @Max(100)
  max: number;

  @IsString()
  @IsNotEmpty()
  remark: string;
}

export class BootstrapGradingSchemeDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  name: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BootstrapGradingBandDto)
  bands: BootstrapGradingBandDto[];
}

export class BootstrapSchoolSetupDto {
  @ValidateNested()
  @Type(() => BootstrapSchoolProfileDto)
  school: BootstrapSchoolProfileDto;

  @ValidateNested()
  @Type(() => BootstrapCampusDto)
  campus: BootstrapCampusDto;

  @ValidateNested()
  @Type(() => BootstrapAcademicYearDto)
  academicYear: BootstrapAcademicYearDto;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BootstrapClassLevelDto)
  classLevels: BootstrapClassLevelDto[];

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BootstrapSubjectDto)
  subjects: BootstrapSubjectDto[];

  @ValidateNested()
  @Type(() => BootstrapGradingSchemeDto)
  gradingScheme: BootstrapGradingSchemeDto;
}
