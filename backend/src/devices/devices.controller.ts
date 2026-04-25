import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { User } from '../users/user.entity';
import { UserRole } from '../users/user-role.enum';
import { RevokeCurrentDeviceDto } from './dto/revoke-current-device.dto';
import { DevicesService } from './devices.service';

@Controller('devices')
@UseGuards(JwtAuthGuard, RolesGuard)
export class DevicesController {
  constructor(private readonly svc: DevicesService) {}

  @Get('trusted')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  listTrustedDevices(@Request() req: { user: User }) {
    return this.svc.listTrustedDevices(req.user);
  }

  @Post('revoke-current')
  @Roles(
    UserRole.Admin,
    UserRole.Cashier,
    UserRole.Teacher,
    UserRole.Parent,
    UserRole.Student,
    UserRole.SupportAdmin,
    UserRole.SupportTechnician,
  )
  revokeCurrentTrustedDevice(
    @Request() req: { user: User },
    @Body() dto: RevokeCurrentDeviceDto,
  ) {
    return this.svc.revokeCurrentTrustedDevice(
      req.user,
      dto.deviceFingerprint,
    );
  }

  @Delete(':id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  revokeTrustedDevice(@Request() req: { user: User }, @Param('id') id: string) {
    return this.svc.revokeTrustedDevice(req.user, id);
  }
}
