import { IsOptional, IsString, MinLength, MaxLength } from 'class-validator';

export class RefreshTokenDto {
  @IsString()
  @MinLength(1)
  refreshToken: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(512)
  deviceFingerprint?: string;
}
