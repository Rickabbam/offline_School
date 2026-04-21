import {
  Controller, Get, Post, Patch, Delete, Param, Body, Query, UseGuards, Request,
} from '@nestjs/common';
import { StaffService } from './staff.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user-role.enum';
import { Staff } from './staff.entity';
import { User } from '../users/user.entity';

@Controller('staff')
@UseGuards(JwtAuthGuard, RolesGuard)
export class StaffController {
  constructor(private readonly svc: StaffService) {}

  @Get()
  findAll(@Request() req: { user: User }, @Query('search') search?: string) {
    return this.svc.findAll(req.user.tenantId!, req.user.schoolId!, search);
  }

  @Get(':id')
  findOne(@Param('id') id: string) { return this.svc.findById(id); }

  @Post()
  @Roles(UserRole.Admin)
  create(@Request() req: { user: User }, @Body() body: Partial<Staff>) {
    return this.svc.create(req.user.tenantId!, req.user.schoolId!, body);
  }

  @Patch(':id')
  @Roles(UserRole.Admin)
  update(@Param('id') id: string, @Body() body: Partial<Staff>) {
    return this.svc.update(id, body);
  }

  @Delete(':id')
  @Roles(UserRole.Admin)
  remove(@Param('id') id: string) { return this.svc.remove(id); }
}
