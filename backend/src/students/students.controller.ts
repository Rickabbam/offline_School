import {
  Controller, Get, Post, Patch, Delete, Param, Body, Query, UseGuards, Request,
} from '@nestjs/common';
import { StudentsService } from './students.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireSchoolScope } from '../auth/request-scope';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user-role.enum';
import { CreateStudentDto } from './dto/create-student.dto';
import { Guardian, Enrollment } from './student.entity';
import { User } from '../users/user.entity';

@Controller('students')
@UseGuards(JwtAuthGuard, RolesGuard)
export class StudentsController {
  constructor(private readonly svc: StudentsService) {}

  @Get()
  @Roles(UserRole.Admin, UserRole.Teacher)
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
  @Roles(UserRole.Admin, UserRole.Teacher)
  findOne(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.findById(scope.tenantId, scope.schoolId, scope.campusId, id);
  }

  @Post()
  @Roles(UserRole.Admin, UserRole.Teacher)
  create(@Request() req: { user: User }, @Body() dto: CreateStudentDto) {
    const scope = requireSchoolScope(req.user);
    return this.svc.create(
      scope.tenantId,
      scope.schoolId,
      scope.campusId,
      dto,
    );
  }

  @Patch(':id')
  @Roles(UserRole.Admin, UserRole.Teacher)
  update(@Request() req: { user: User }, @Param('id') id: string, @Body() body: Partial<CreateStudentDto>) {
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

  // ─── Guardians ──────────────────────────────────────────────────────────────
  @Get(':id/guardians')
  @Roles(UserRole.Admin, UserRole.Teacher)
  getGuardians(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.getGuardians(
      scope.tenantId,
      scope.schoolId,
      scope.campusId,
      id,
    );
  }

  @Post(':id/guardians')
  @Roles(UserRole.Admin, UserRole.Teacher)
  addGuardian(
    @Request() req: { user: User },
    @Param('id') studentId: string,
    @Body() body: Partial<Guardian>,
  ) {
    const scope = requireSchoolScope(req.user);
    return this.svc.addGuardian(
      scope.tenantId,
      scope.schoolId,
      scope.campusId,
      {
        ...body,
        studentId,
      },
    );
  }

  // ─── Enrollments ────────────────────────────────────────────────────────────
  @Get(':id/enrollments')
  @Roles(UserRole.Admin, UserRole.Teacher)
  getEnrollments(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.getEnrollments(
      scope.tenantId,
      scope.schoolId,
      scope.campusId,
      id,
    );
  }

  @Post(':id/enrollments')
  @Roles(UserRole.Admin)
  enroll(
    @Request() req: { user: User },
    @Param('id') studentId: string,
    @Body() body: Partial<Enrollment>,
  ) {
    const scope = requireSchoolScope(req.user);
    return this.svc.enroll(
      scope.tenantId,
      scope.schoolId,
      scope.campusId,
      {
        ...body,
        studentId,
      },
    );
  }
}
