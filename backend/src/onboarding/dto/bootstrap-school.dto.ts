import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsEmail,
  IsEnum,
  IsInt,
  IsNumber,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
  ValidateIf,
} from "class-validator";
import { Type } from "class-transformer";
import { SchoolType } from "../../schools/school.entity";

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

export class BootstrapStaffRoleDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  role: string;

  @IsBoolean()
  enabled: boolean;

  @IsInt()
  @Min(0)
  headcount: number;
}

export class BootstrapFeeCategoryDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(150)
  name: string;

  @IsNumber()
  @Min(0)
  defaultAmount: number;

  @IsString()
  @IsNotEmpty()
  @MaxLength(30)
  billingTerm: string;
}

export class BootstrapReceiptFormatDto {
  @IsOptional()
  @IsString()
  @MaxLength(255)
  headerLine1?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  headerLine2?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  footerNote?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(30)
  receiptPrefix: string;

  @IsInt()
  @Min(1)
  nextReceiptNumber: number;
}

export class BootstrapNotificationSettingsDto {
  @IsBoolean()
  smsEnabled: boolean;

  @IsBoolean()
  paymentReceiptsEnabled: boolean;

  @IsBoolean()
  feeRemindersEnabled: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  senderId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  providerName?: string;
}

export class BootstrapOnboardingDefaultsDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BootstrapStaffRoleDto)
  staffRoles: BootstrapStaffRoleDto[];

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BootstrapFeeCategoryDto)
  feeCategories: BootstrapFeeCategoryDto[];

  @ValidateNested()
  @Type(() => BootstrapReceiptFormatDto)
  receiptFormat: BootstrapReceiptFormatDto;

  @ValidateNested()
  @Type(() => BootstrapNotificationSettingsDto)
  notifications: BootstrapNotificationSettingsDto;
}

export class BootstrapDeviceRegistrationDto {
  @IsBoolean()
  registerOfflineAccess: boolean;

  @ValidateIf((value: BootstrapDeviceRegistrationDto) => value.registerOfflineAccess)
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  deviceName: string;

  @ValidateIf((value: BootstrapDeviceRegistrationDto) => value.registerOfflineAccess)
  @IsString()
  @IsNotEmpty()
  @MaxLength(512)
  deviceFingerprint: string;
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

  @ValidateNested()
  @Type(() => BootstrapOnboardingDefaultsDto)
  onboardingDefaults: BootstrapOnboardingDefaultsDto;

  @ValidateNested()
  @Type(() => BootstrapDeviceRegistrationDto)
  deviceRegistration: BootstrapDeviceRegistrationDto;
}
