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
  findAll(
    @Request() req: { user: User },
    @Query('status') status?: ApplicantStatus,
  ) {
    return this.svc.findAll(req.user.tenantId!, req.user.schoolId!, status);
  }

  @Get(':id')
  findOne(@Param('id') id: string) { return this.svc.findById(id); }

  @Post()
  @Roles(UserRole.Admin, UserRole.Teacher)
  create(@Request() req: { user: User }, @Body() body: Partial<Applicant>) {
    return this.svc.create(req.user.tenantId!, req.user.schoolId!, body);
  }

  @Patch(':id')
  @Roles(UserRole.Admin, UserRole.Teacher)
  update(@Param('id') id: string, @Body() body: Partial<Applicant>) {
    return this.svc.update(id, body);
  }

  @Post(':id/admit')
  @Roles(UserRole.Admin)
  admit(@Param('id') id: string) { return this.svc.admit(id); }

  @Post(':id/enroll')
  @Roles(UserRole.Admin)
  enroll(@Param('id') id: string) { return this.svc.enroll(id); }

  @Post(':id/reject')
  @Roles(UserRole.Admin)
  reject(@Param('id') id: string) { return this.svc.reject(id); }
}
