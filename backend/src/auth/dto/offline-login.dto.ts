import { IsString, MaxLength, MinLength } from 'class-validator';

export class OfflineLoginDto {
  @IsString()
  @MinLength(1)
  @MaxLength(512)
  deviceFingerprint: string;

  @IsString()
  @MinLength(1)
  @MaxLength(512)
  offlineToken: string;
}
