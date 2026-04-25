import {
  Controller, Get, Post, Patch, Delete, Param, Body, UseGuards, Request,
} from '@nestjs/common';
import { SchoolsService } from './schools.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireSchoolScope, requireTenantScope } from '../auth/request-scope';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user-role.enum';
import { School } from './school.entity';
import { User } from '../users/user.entity';

@Controller('schools')
@UseGuards(JwtAuthGuard, RolesGuard)
export class SchoolsController {
  constructor(private readonly svc: SchoolsService) {}

  @Get()
  @Roles(UserRole.Admin, UserRole.SupportAdmin)
  findAll(@Request() req: { user: User }) {
    const scope = requireTenantScope(req.user);
    return this.svc.findAll(
      scope.tenantId,
      req.user.role === UserRole.SupportAdmin ? null : requireSchoolScope(req.user).schoolId,
    );
  }

  @Get(':id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin)
  findOne(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireTenantScope(req.user);
    return this.svc.findById(
      scope.tenantId,
      id,
      req.user.role === UserRole.SupportAdmin ? null : requireSchoolScope(req.user).schoolId,
    );
  }

  @Post()
  @Roles(UserRole.SupportAdmin)
  create(@Request() req: { user: User }, @Body() body: Partial<School>) {
    const scope = requireTenantScope(req.user);
    return this.svc.create(scope.tenantId, body);
  }

  @Patch(':id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin)
  update(@Request() req: { user: User }, @Param('id') id: string, @Body() body: Partial<School>) {
    const scope = requireTenantScope(req.user);
    return this.svc.update(
      scope.tenantId,
      id,
      body,
      req.user.role === UserRole.SupportAdmin ? null : requireSchoolScope(req.user).schoolId,
    );
  }

  @Delete(':id')
  @Roles(UserRole.SupportAdmin)
  remove(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireTenantScope(req.user);
    return this.svc.remove(scope.tenantId, id);
  }
}
