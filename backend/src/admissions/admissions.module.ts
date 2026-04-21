import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Applicant } from './applicant.entity';
import { Student } from '../students/student.entity';
import { AdmissionsService } from './admissions.service';
import { AdmissionsController } from './admissions.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Applicant, Student])],
  providers: [AdmissionsService],
  controllers: [AdmissionsController],
  exports: [AdmissionsService],
})
export class AdmissionsModule {}
