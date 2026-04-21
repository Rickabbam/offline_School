import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  AcademicYear, Term, ClassLevel, ClassArm, Subject, GradingScheme,
} from './academic.entity';
import { AcademicService } from './academic.service';
import { AcademicController } from './academic.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      AcademicYear, Term, ClassLevel, ClassArm, Subject, GradingScheme,
    ]),
  ],
  providers: [AcademicService],
  controllers: [AcademicController],
  exports: [AcademicService],
})
export class AcademicModule {}
