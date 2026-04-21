import { IsString, MinLength, MaxLength } from 'class-validator';

export class RefreshTokenDto {
  @IsString()
  @MinLength(1)
  refreshToken: string;
}
