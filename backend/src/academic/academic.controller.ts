import {
  Controller, Get, Post, Patch, Body, Param, Query, UseGuards, Request,
} from '@nestjs/common';
import { AcademicService } from './academic.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import {
  AcademicYear, Term, ClassLevel, ClassArm, Subject, GradingScheme,
} from './academic.entity';
import { User } from '../users/user.entity';

@Controller('academic')
@UseGuards(JwtAuthGuard)
export class AcademicController {
  constructor(private readonly svc: AcademicService) {}

  @Get('years')
  getYears(@Request() req: { user: User }) {
    return this.svc.getYears(req.user.schoolId!);
  }

  @Post('years')
  createYear(@Request() req: { user: User }, @Body() body: Partial<AcademicYear>) {
    return this.svc.createYear({ ...body, tenantId: req.user.tenantId!, schoolId: req.user.schoolId! });
  }

  @Patch('years/:id')
  updateYear(@Param('id') id: string, @Body() body: Partial<AcademicYear>) {
    return this.svc.updateYear(id, body);
  }

  @Get('terms')
  getTerms(@Request() req: { user: User }, @Query('yearId') yearId?: string) {
    return this.svc.getTerms(req.user.schoolId!, yearId);
  }

  @Post('terms')
  createTerm(@Request() req: { user: User }, @Body() body: Partial<Term>) {
    return this.svc.createTerm({ ...body, tenantId: req.user.tenantId!, schoolId: req.user.schoolId! });
  }

  @Get('class-levels')
  getClassLevels(@Request() req: { user: User }) {
    return this.svc.getClassLevels(req.user.schoolId!);
  }

  @Post('class-levels')
  createClassLevel(@Request() req: { user: User }, @Body() body: Partial<ClassLevel>) {
    return this.svc.createClassLevel({ ...body, tenantId: req.user.tenantId!, schoolId: req.user.schoolId! });
  }

  @Get('class-arms')
  getClassArms(@Request() req: { user: User }, @Query('levelId') levelId?: string) {
    return this.svc.getClassArms(req.user.schoolId!, levelId);
  }

  @Post('class-arms')
  createClassArm(@Request() req: { user: User }, @Body() body: Partial<ClassArm>) {
    return this.svc.createClassArm({ ...body, tenantId: req.user.tenantId!, schoolId: req.user.schoolId! });
  }

  @Get('subjects')
  getSubjects(@Request() req: { user: User }) {
    return this.svc.getSubjects(req.user.schoolId!);
  }

  @Post('subjects')
  createSubject(@Request() req: { user: User }, @Body() body: Partial<Subject>) {
    return this.svc.createSubject({ ...body, tenantId: req.user.tenantId!, schoolId: req.user.schoolId! });
  }

  @Get('grading-schemes')
  getGradingSchemes(@Request() req: { user: User }) {
    return this.svc.getGradingSchemes(req.user.schoolId!);
  }

  @Post('grading-schemes')
  createGradingScheme(@Request() req: { user: User }, @Body() body: Partial<GradingScheme>) {
    return this.svc.createGradingScheme({ ...body, tenantId: req.user.tenantId!, schoolId: req.user.schoolId! });
  }
}
