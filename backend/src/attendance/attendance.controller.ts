import {
  Controller, Get, Post, Param, Body, Query, UseGuards, Request,
} from '@nestjs/common';
import { AttendanceService } from './attendance.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user-role.enum';
import { AttendanceRecord } from './attendance-record.entity';
import { User } from '../users/user.entity';

@Controller('attendance')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AttendanceController {
  constructor(private readonly svc: AttendanceService) {}

  @Get()
  findByDate(
    @Request() req: { user: User },
    @Query('classArmId') classArmId: string,
    @Query('date') date: string,
  ) {
    return this.svc.findByDate(
      req.user.tenantId!,
      req.user.schoolId!,
      classArmId,
      date,
    );
  }

  @Get('student/:studentId')
  findByStudent(
    @Param('studentId') studentId: string,
    @Query('termId') termId?: string,
  ) {
    return this.svc.findByStudent(studentId, termId);
  }

  @Get('summary')
  summary(
    @Request() req: { user: User },
    @Query('classArmId') classArmId: string,
    @Query('termId') termId: string,
  ) {
    return this.svc.summary(req.user.schoolId!, classArmId, termId);
  }

  /** Mark attendance for a single student */
  @Post()
  @Roles(UserRole.Teacher, UserRole.Admin)
  mark(
    @Request() req: { user: User },
    @Body() body: Partial<AttendanceRecord>,
  ) {
    return this.svc.upsert(req.user.tenantId!, req.user.schoolId!, {
      ...body,
      recordedByUserId: req.user.id,
    });
  }

  /** Mark attendance for an entire class in one request */
  @Post('bulk')
  @Roles(UserRole.Teacher, UserRole.Admin)
  bulkMark(
    @Request() req: { user: User },
    @Body() body: { records: Partial<AttendanceRecord>[] },
  ) {
    const records = body.records.map((r) => ({
      ...r,
      recordedByUserId: req.user.id,
    }));
    return this.svc.bulkUpsert(req.user.tenantId!, req.user.schoolId!, records);
  }
}
