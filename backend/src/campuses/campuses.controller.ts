import {
  Controller, Get, Post, Patch, Delete, Param, Body, UseGuards, Request,
} from '@nestjs/common';
import { CampusesService } from './campuses.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireSchoolScope } from '../auth/request-scope';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user-role.enum';
import { Campus } from './campus.entity';
import { User } from '../users/user.entity';

@Controller('campuses')
@UseGuards(JwtAuthGuard, RolesGuard)
export class CampusesController {
  constructor(private readonly svc: CampusesService) {}

  @Get()
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  findAll(@Request() req: { user: User }) {
    const scope = requireSchoolScope(req.user);
    return this.svc.findAll(
      scope.tenantId,
      scope.schoolId,
      req.user.role === UserRole.SupportTechnician ? scope.campusId : null,
    );
  }

  @Get(':id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  findOne(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.findById(
      scope.tenantId,
      id,
      scope.schoolId,
      req.user.role === UserRole.SupportTechnician ? scope.campusId : null,
    );
  }

  @Post()
  @Roles(UserRole.SupportAdmin)
  create(@Request() req: { user: User }, @Body() body: Partial<Campus>) {
    const scope = requireSchoolScope(req.user);
    return this.svc.create(scope.tenantId, scope.schoolId, body);
  }

  @Patch(':id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin)
  update(@Request() req: { user: User }, @Param('id') id: string, @Body() body: Partial<Campus>) {
    const scope = requireSchoolScope(req.user);
    return this.svc.update(scope.tenantId, id, body, scope.schoolId);
  }

  @Delete(':id')
  @Roles(UserRole.SupportAdmin)
  remove(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.remove(scope.tenantId, id, scope.schoolId);
  }
}
