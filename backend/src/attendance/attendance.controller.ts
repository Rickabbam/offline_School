import {
  Controller, Get, Post, Param, Body, Query, UseGuards, Request,
} from '@nestjs/common';
import { AttendanceService } from './attendance.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireSchoolScope } from '../auth/request-scope';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user-role.enum';
import { User } from '../users/user.entity';
import { AttendanceRecord } from './attendance-record.entity';
import { MarkAttendanceDto } from './dto/mark-attendance.dto';
import { BulkMarkAttendanceDto } from './dto/bulk-mark-attendance.dto';

@Controller('attendance')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AttendanceController {
  constructor(private readonly svc: AttendanceService) {}

  @Get()
  @Roles(UserRole.Teacher, UserRole.Admin)
  findByDate(
    @Request() req: { user: User },
    @Query('classArmId') classArmId: string,
    @Query('date') date: string,
  ) {
    const scope = requireSchoolScope(req.user);
    return this.svc.findByDate(
      scope.tenantId,
      scope.schoolId,
      scope.campusId,
      classArmId,
      date,
    );
  }

  @Get('student/:studentId')
  @Roles(UserRole.Teacher, UserRole.Admin)
  findByStudent(
    @Request() req: { user: User },
    @Param('studentId') studentId: string,
    @Query('termId') termId?: string,
  ) {
    const scope = requireSchoolScope(req.user);
    return this.svc.findByStudent(
      scope.tenantId,
      scope.schoolId,
      scope.campusId,
      studentId,
      termId,
    );
  }

  @Get('summary')
  @Roles(UserRole.Teacher, UserRole.Admin)
  summary(
    @Request() req: { user: User },
    @Query('classArmId') classArmId: string,
    @Query('termId') termId: string,
  ) {
    const scope = requireSchoolScope(req.user);
    return this.svc.summary(
      scope.tenantId,
      scope.schoolId,
      scope.campusId,
      classArmId,
      termId,
    );
  }

  /** Mark attendance for a single student */
  @Post()
  @Roles(UserRole.Teacher, UserRole.Admin)
  mark(
    @Request() req: { user: User },
    @Body() body: MarkAttendanceDto,
  ) {
    const scope = requireSchoolScope(req.user);
    return this.svc.upsert(scope.tenantId, scope.schoolId, scope.campusId, {
      ...body,
      recordedByUserId: req.user.id,
    });
  }

  /** Mark attendance for an entire class in one request */
  @Post('bulk')
  @Roles(UserRole.Teacher, UserRole.Admin)
  bulkMark(
    @Request() req: { user: User },
    @Body() body: BulkMarkAttendanceDto,
  ) {
    const scope = requireSchoolScope(req.user);
    const records = body.records.map((r: MarkAttendanceDto): Partial<AttendanceRecord> => ({
      ...r,
      recordedByUserId: req.user.id,
    }));
    return this.svc.bulkUpsert(
      scope.tenantId,
      scope.schoolId,
      scope.campusId,
      records,
    );
  }
}
