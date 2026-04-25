import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AcademicYear, ClassArm } from '../academic/academic.entity';
import { Campus } from '../campuses/campus.entity';
import { Student, Guardian, Enrollment } from './student.entity';
import { StudentsService } from './students.service';
import { StudentsController } from './students.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Student, Guardian, Enrollment, AcademicYear, ClassArm, Campus])],
  providers: [StudentsService],
  controllers: [StudentsController],
  exports: [StudentsService],
})
export class StudentsModule {}
