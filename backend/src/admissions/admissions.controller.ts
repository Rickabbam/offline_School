import {
  Controller, Get, Post, Patch, Param, Body, Query, UseGuards, Request,
} from '@nestjs/common';
import { AdmissionsService } from './admissions.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user-role.enum';
import { Applicant, ApplicantStatus } from './applicant.entity';
import { User } from '../users/user.entity';

@Controller('admissions')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdmissionsController {
  constructor(private readonly svc: AdmissionsService) {}

  @Get()
  @Roles(UserRole.Admin, UserRole.Teacher)
  findAll(
    @Request() req: { user: User },
    @Query('status') status?: ApplicantStatus,
  ) {
    return this.svc.findAll(req.user.tenantId!, req.user.schoolId!, status);
  }

  @Get(':id')
  @Roles(UserRole.Admin, UserRole.Teacher)
  findOne(@Request() req: { user: User }, @Param('id') id: string) {
    return this.svc.findById(req.user.tenantId!, req.user.schoolId!, id);
  }

  @Post()
  @Roles(UserRole.Admin, UserRole.Teacher)
  create(@Request() req: { user: User }, @Body() body: Partial<Applicant>) {
    return this.svc.create(req.user.tenantId!, req.user.schoolId!, body);
  }

  @Patch(':id')
  @Roles(UserRole.Admin, UserRole.Teacher)
  update(@Request() req: { user: User }, @Param('id') id: string, @Body() body: Partial<Applicant>) {
    return this.svc.update(req.user.tenantId!, req.user.schoolId!, id, body);
  }

  @Post(':id/admit')
  @Roles(UserRole.Admin)
  admit(@Request() req: { user: User }, @Param('id') id: string) {
    return this.svc.admit(req.user.tenantId!, req.user.schoolId!, id);
  }

  @Post(':id/enroll')
  @Roles(UserRole.Admin)
  enroll(@Request() req: { user: User }, @Param('id') id: string) {
    return this.svc.enroll(req.user.tenantId!, req.user.schoolId!, id);
  }

  @Post(':id/reject')
  @Roles(UserRole.Admin)
  reject(@Request() req: { user: User }, @Param('id') id: string) {
    return this.svc.reject(req.user.tenantId!, req.user.schoolId!, id);
  }
}
