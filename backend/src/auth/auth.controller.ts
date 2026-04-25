import {
  Controller,
  Post,
  Body,
  Get,
  UseGuards,
  Request,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { OfflineLoginDto } from './dto/offline-login.dto';
import { LogoutDto } from './dto/logout.dto';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { JwtAuthGuard } from './jwt-auth.guard';
import { User } from '../users/user.entity';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  /** POST /auth/login — email + password → JWT pair */
  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  /** POST /auth/offline-login — trusted device token → JWT pair */
  @Post('offline-login')
  @HttpCode(HttpStatus.OK)
  offlineLogin(@Body() dto: OfflineLoginDto) {
    return this.authService.offlineLogin(
      dto.deviceFingerprint,
      dto.offlineToken,
    );
  }

  /** POST /auth/refresh — refresh token → new JWT pair */
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refreshToken(
      dto.refreshToken,
      dto.deviceFingerprint,
    );
  }

  /** POST /auth/logout — invalidate the current session version */
  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  logout(@Request() req: { user: User }, @Body() dto: LogoutDto) {
    return this.authService.logout(req.user, dto.deviceFingerprint);
  }

  /** POST /auth/register-device — register a trusted desktop device */
  @Post('register-device')
  @UseGuards(JwtAuthGuard)
  registerDevice(
    @Request() req: { user: User },
    @Body() dto: RegisterDeviceDto,
  ) {
    return this.authService.registerDevice(req.user.id, dto);
  }

  /** GET /auth/me — current authenticated user */
  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@Request() req: { user: User }) {
    const u = req.user;
    return {
      id: u.id,
      email: u.email,
      fullName: u.fullName,
      role: u.role,
      tenantId: u.tenantId,
      schoolId: u.schoolId,
      campusId: u.campusId,
    };
  }
}
