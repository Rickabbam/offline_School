import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditModule } from '../audit/audit.module';
import { Applicant } from './applicant.entity';
import { AcademicYear, ClassArm } from '../academic/academic.entity';
import { Enrollment, Guardian, Student } from '../students/student.entity';
import { Campus } from '../campuses/campus.entity';
import { AdmissionsService } from './admissions.service';
import { AdmissionsController } from './admissions.controller';

@Module({
  imports: [
    AuditModule,
    TypeOrmModule.forFeature([
      Applicant,
      Student,
      Guardian,
      Enrollment,
      ClassArm,
      AcademicYear,
      Campus,
    ]),
  ],
  providers: [AdmissionsService],
  controllers: [AdmissionsController],
  exports: [AdmissionsService],
})
export class AdmissionsModule {}
