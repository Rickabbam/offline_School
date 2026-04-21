import {
  Controller, Get, Post, Patch, Delete, Param, Body, Query, UseGuards, Request,
} from '@nestjs/common';
import { StudentsService } from './students.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
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
  findAll(@Request() req: { user: User }, @Query('search') search?: string) {
    return this.svc.findAll(req.user.tenantId!, req.user.schoolId!, search);
  }

  @Get(':id')
  findOne(@Param('id') id: string) { return this.svc.findById(id); }

  @Post()
  @Roles(UserRole.Admin, UserRole.Teacher)
  create(@Request() req: { user: User }, @Body() dto: CreateStudentDto) {
    return this.svc.create(req.user.tenantId!, req.user.schoolId!, dto);
  }

  @Patch(':id')
  @Roles(UserRole.Admin, UserRole.Teacher)
  update(@Param('id') id: string, @Body() body: Partial<CreateStudentDto>) {
    return this.svc.update(id, body);
  }

  @Delete(':id')
  @Roles(UserRole.Admin)
  remove(@Param('id') id: string) { return this.svc.remove(id); }

  // ─── Guardians ──────────────────────────────────────────────────────────────
  @Get(':id/guardians')
  getGuardians(@Param('id') id: string) { return this.svc.getGuardians(id); }

  @Post(':id/guardians')
  @Roles(UserRole.Admin, UserRole.Teacher)
  addGuardian(
    @Request() req: { user: User },
    @Param('id') studentId: string,
    @Body() body: Partial<Guardian>,
  ) {
    return this.svc.addGuardian(req.user.tenantId!, req.user.schoolId!, {
      ...body,
      studentId,
    });
  }

  // ─── Enrollments ────────────────────────────────────────────────────────────
  @Get(':id/enrollments')
  getEnrollments(@Param('id') id: string) { return this.svc.getEnrollments(id); }

  @Post(':id/enrollments')
  @Roles(UserRole.Admin)
  enroll(
    @Request() req: { user: User },
    @Param('id') studentId: string,
    @Body() body: Partial<Enrollment>,
  ) {
    return this.svc.enroll(req.user.tenantId!, req.user.schoolId!, {
      ...body,
      studentId,
    });
  }
}
