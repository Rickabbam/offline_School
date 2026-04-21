import { IsString, MinLength, MaxLength } from 'class-validator';

export class RegisterDeviceDto {
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  deviceName: string;

  @IsString()
  @MinLength(1)
  @MaxLength(512)
  deviceFingerprint: string;
}
