import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import { AcademicService } from './academic.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import {
  AcademicYear,
  ClassArm,
  ClassLevel,
  GradingScheme,
  Subject,
  Term,
} from './academic.entity';
import { User } from '../users/user.entity';
import { UserRole } from '../users/user-role.enum';

@Controller('academic')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AcademicController {
  constructor(private readonly svc: AcademicService) {}

  @Get('years')
  @Roles(UserRole.Admin, UserRole.Teacher, UserRole.SupportAdmin, UserRole.SupportTechnician)
  getYears(@Request() req: { user: User }) {
    return this.svc.getYears(req.user.schoolId!);
  }

  @Post('years')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  createYear(@Request() req: { user: User }, @Body() body: Partial<AcademicYear>) {
    return this.svc.createYear({
      ...body,
      tenantId: req.user.tenantId!,
      schoolId: req.user.schoolId!,
    });
  }

  @Patch('years/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  updateYear(
    @Request() req: { user: User },
    @Param('id') id: string,
    @Body() body: Partial<AcademicYear>,
  ) {
    return this.svc.updateYear(req.user.tenantId!, req.user.schoolId!, id, body);
  }

  @Delete('years/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  removeYear(@Request() req: { user: User }, @Param('id') id: string) {
    return this.svc.removeYear(req.user.tenantId!, req.user.schoolId!, id);
  }

  @Get('terms')
  @Roles(UserRole.Admin, UserRole.Teacher, UserRole.SupportAdmin, UserRole.SupportTechnician)
  getTerms(@Request() req: { user: User }, @Query('yearId') yearId?: string) {
    return this.svc.getTerms(req.user.schoolId!, yearId);
  }

  @Post('terms')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  createTerm(@Request() req: { user: User }, @Body() body: Partial<Term>) {
    return this.svc.createTerm({
      ...body,
      tenantId: req.user.tenantId!,
      schoolId: req.user.schoolId!,
    });
  }

  @Patch('terms/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  updateTerm(@Request() req: { user: User }, @Param('id') id: string, @Body() body: Partial<Term>) {
    return this.svc.updateTerm(req.user.tenantId!, req.user.schoolId!, id, body);
  }

  @Delete('terms/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  removeTerm(@Request() req: { user: User }, @Param('id') id: string) {
    return this.svc.removeTerm(req.user.tenantId!, req.user.schoolId!, id);
  }

  @Get('class-levels')
  @Roles(UserRole.Admin, UserRole.Teacher, UserRole.SupportAdmin, UserRole.SupportTechnician)
  getClassLevels(@Request() req: { user: User }) {
    return this.svc.getClassLevels(req.user.schoolId!);
  }

  @Post('class-levels')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  createClassLevel(@Request() req: { user: User }, @Body() body: Partial<ClassLevel>) {
    return this.svc.createClassLevel({
      ...body,
      tenantId: req.user.tenantId!,
      schoolId: req.user.schoolId!,
    });
  }

  @Patch('class-levels/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  updateClassLevel(
    @Request() req: { user: User },
    @Param('id') id: string,
    @Body() body: Partial<ClassLevel>,
  ) {
    return this.svc.updateClassLevel(req.user.tenantId!, req.user.schoolId!, id, body);
  }

  @Delete('class-levels/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  removeClassLevel(@Request() req: { user: User }, @Param('id') id: string) {
    return this.svc.removeClassLevel(req.user.tenantId!, req.user.schoolId!, id);
  }

  @Get('class-arms')
  @Roles(UserRole.Admin, UserRole.Teacher, UserRole.SupportAdmin, UserRole.SupportTechnician)
  getClassArms(@Request() req: { user: User }, @Query('levelId') levelId?: string) {
    return this.svc.getClassArms(req.user.schoolId!, levelId);
  }

  @Post('class-arms')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  createClassArm(@Request() req: { user: User }, @Body() body: Partial<ClassArm>) {
    return this.svc.createClassArm({
      ...body,
      tenantId: req.user.tenantId!,
      schoolId: req.user.schoolId!,
    });
  }

  @Patch('class-arms/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  updateClassArm(@Request() req: { user: User }, @Param('id') id: string, @Body() body: Partial<ClassArm>) {
    return this.svc.updateClassArm(req.user.tenantId!, req.user.schoolId!, id, body);
  }

  @Delete('class-arms/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  removeClassArm(@Request() req: { user: User }, @Param('id') id: string) {
    return this.svc.removeClassArm(req.user.tenantId!, req.user.schoolId!, id);
  }

  @Get('subjects')
  @Roles(UserRole.Admin, UserRole.Teacher, UserRole.SupportAdmin, UserRole.SupportTechnician)
  getSubjects(@Request() req: { user: User }) {
    return this.svc.getSubjects(req.user.schoolId!);
  }

  @Post('subjects')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  createSubject(@Request() req: { user: User }, @Body() body: Partial<Subject>) {
    return this.svc.createSubject({
      ...body,
      tenantId: req.user.tenantId!,
      schoolId: req.user.schoolId!,
    });
  }

  @Patch('subjects/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  updateSubject(@Request() req: { user: User }, @Param('id') id: string, @Body() body: Partial<Subject>) {
    return this.svc.updateSubject(req.user.tenantId!, req.user.schoolId!, id, body);
  }

  @Delete('subjects/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  removeSubject(@Request() req: { user: User }, @Param('id') id: string) {
    return this.svc.removeSubject(req.user.tenantId!, req.user.schoolId!, id);
  }

  @Get('grading-schemes')
  @Roles(UserRole.Admin, UserRole.Teacher, UserRole.SupportAdmin, UserRole.SupportTechnician)
  getGradingSchemes(@Request() req: { user: User }) {
    return this.svc.getGradingSchemes(req.user.schoolId!);
  }

  @Post('grading-schemes')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  createGradingScheme(@Request() req: { user: User }, @Body() body: Partial<GradingScheme>) {
    return this.svc.createGradingScheme({
      ...body,
      tenantId: req.user.tenantId!,
      schoolId: req.user.schoolId!,
    });
  }

  @Patch('grading-schemes/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  updateGradingScheme(
    @Request() req: { user: User },
    @Param('id') id: string,
    @Body() body: Partial<GradingScheme>,
  ) {
    return this.svc.updateGradingScheme(req.user.tenantId!, req.user.schoolId!, id, body);
  }

  @Delete('grading-schemes/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  removeGradingScheme(@Request() req: { user: User }, @Param('id') id: string) {
    return this.svc.removeGradingScheme(req.user.tenantId!, req.user.schoolId!, id);
  }
}
