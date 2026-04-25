import {
  Controller, Get, Post, Patch, Param, Body, Query, UseGuards, Request,
} from '@nestjs/common';
import { AdmissionsService } from './admissions.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireSchoolScope } from '../auth/request-scope';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user-role.enum';
import { Applicant, ApplicantStatus } from './applicant.entity';
import { User } from '../users/user.entity';
import { EnrollApplicantDto } from './dto/enroll-applicant.dto';
import { CreateApplicantDto } from './dto/create-applicant.dto';
import { UpdateApplicantDto } from './dto/update-applicant.dto';

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
    const scope = requireSchoolScope(req.user);
    return this.svc.findAll(scope.tenantId, scope.schoolId, status);
  }

  @Get(':id')
  @Roles(UserRole.Admin, UserRole.Teacher)
  findOne(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.findById(scope.tenantId, scope.schoolId, id);
  }

  @Post()
  @Roles(UserRole.Admin, UserRole.Teacher)
  create(@Request() req: { user: User }, @Body() body: CreateApplicantDto) {
    const scope = requireSchoolScope(req.user);
    return this.svc.create(scope.tenantId, scope.schoolId, body);
  }

  @Patch(':id')
  @Roles(UserRole.Admin, UserRole.Teacher)
  update(@Request() req: { user: User }, @Param('id') id: string, @Body() body: UpdateApplicantDto) {
    const scope = requireSchoolScope(req.user);
    return this.svc.update(scope.tenantId, scope.schoolId, id, body);
  }

  @Post(':id/admit')
  @Roles(UserRole.Admin)
  admit(@Request() req: { user: User }, @Param('id') id: string) {
    requireSchoolScope(req.user);
    return this.svc.admit(req.user, id);
  }

  @Post(':id/enroll')
  @Roles(UserRole.Admin)
  enroll(
    @Request() req: { user: User },
    @Param('id') id: string,
    @Body() body: EnrollApplicantDto,
  ) {
    requireSchoolScope(req.user);
    return this.svc.enroll(req.user, id, body);
  }

  @Post(':id/reject')
  @Roles(UserRole.Admin)
  reject(@Request() req: { user: User }, @Param('id') id: string) {
    requireSchoolScope(req.user);
    return this.svc.reject(req.user, id);
  }
}
