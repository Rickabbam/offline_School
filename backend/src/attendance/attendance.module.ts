import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AcademicYear, ClassArm, Term } from '../academic/academic.entity';
import { Student } from '../students/student.entity';
import { AttendanceRecord } from './attendance-record.entity';
import { AttendanceService } from './attendance.service';
import { AttendanceController } from './attendance.controller';

@Module({
  imports: [TypeOrmModule.forFeature([AttendanceRecord, AcademicYear, ClassArm, Student, Term])],
  providers: [AttendanceService],
  controllers: [AttendanceController],
  exports: [AttendanceService],
})
export class AttendanceModule {}
