import {
  Controller, Get, Post, Patch, Delete, Param, Body, Query, UseGuards, Request,
} from '@nestjs/common';
import { StaffService } from './staff.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireSchoolScope } from '../auth/request-scope';
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
  @Roles(UserRole.Admin)
  findAll(@Request() req: { user: User }, @Query('search') search?: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.findAll(
      scope.tenantId,
      scope.schoolId,
      scope.campusId,
      search,
    );
  }

  @Get(':id')
  @Roles(UserRole.Admin)
  findOne(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.findById(scope.tenantId, scope.schoolId, scope.campusId, id);
  }

  @Post()
  @Roles(UserRole.Admin)
  create(@Request() req: { user: User }, @Body() body: Partial<Staff>) {
    const scope = requireSchoolScope(req.user);
    return this.svc.create(
      scope.tenantId,
      scope.schoolId,
      scope.campusId,
      body,
    );
  }

  @Patch(':id')
  @Roles(UserRole.Admin)
  update(@Request() req: { user: User }, @Param('id') id: string, @Body() body: Partial<Staff>) {
    const scope = requireSchoolScope(req.user);
    return this.svc.update(
      scope.tenantId,
      scope.schoolId,
      scope.campusId,
      id,
      body,
    );
  }

  @Delete(':id')
  @Roles(UserRole.Admin)
  remove(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.remove(scope.tenantId, scope.schoolId, scope.campusId, id);
  }
}
