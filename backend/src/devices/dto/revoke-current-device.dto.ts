import { IsString, MaxLength, MinLength } from 'class-validator';

export class RevokeCurrentDeviceDto {
  @IsString()
  @MinLength(1)
  @MaxLength(512)
  deviceFingerprint: string;
}
