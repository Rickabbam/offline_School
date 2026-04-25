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
import { requireSchoolScope } from '../auth/request-scope';
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
    const scope = requireSchoolScope(req.user);
    return this.svc.getYears(scope.tenantId, scope.schoolId);
  }

  @Post('years')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  createYear(@Request() req: { user: User }, @Body() body: Partial<AcademicYear>) {
    const scope = requireSchoolScope(req.user);
    return this.svc.createYear({
      ...body,
      tenantId: scope.tenantId,
      schoolId: scope.schoolId,
    });
  }

  @Patch('years/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  updateYear(
    @Request() req: { user: User },
    @Param('id') id: string,
    @Body() body: Partial<AcademicYear>,
  ) {
    const scope = requireSchoolScope(req.user);
    return this.svc.updateYear(scope.tenantId, scope.schoolId, id, body);
  }

  @Delete('years/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  removeYear(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.removeYear(scope.tenantId, scope.schoolId, id);
  }

  @Get('terms')
  @Roles(UserRole.Admin, UserRole.Teacher, UserRole.SupportAdmin, UserRole.SupportTechnician)
  getTerms(@Request() req: { user: User }, @Query('yearId') yearId?: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.getTerms(scope.tenantId, scope.schoolId, yearId);
  }

  @Post('terms')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  createTerm(@Request() req: { user: User }, @Body() body: Partial<Term>) {
    const scope = requireSchoolScope(req.user);
    return this.svc.createTerm({
      ...body,
      tenantId: scope.tenantId,
      schoolId: scope.schoolId,
    });
  }

  @Patch('terms/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  updateTerm(@Request() req: { user: User }, @Param('id') id: string, @Body() body: Partial<Term>) {
    const scope = requireSchoolScope(req.user);
    return this.svc.updateTerm(scope.tenantId, scope.schoolId, id, body);
  }

  @Delete('terms/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  removeTerm(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.removeTerm(scope.tenantId, scope.schoolId, id);
  }

  @Get('class-levels')
  @Roles(UserRole.Admin, UserRole.Teacher, UserRole.SupportAdmin, UserRole.SupportTechnician)
  getClassLevels(@Request() req: { user: User }) {
    const scope = requireSchoolScope(req.user);
    return this.svc.getClassLevels(scope.tenantId, scope.schoolId);
  }

  @Post('class-levels')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  createClassLevel(@Request() req: { user: User }, @Body() body: Partial<ClassLevel>) {
    const scope = requireSchoolScope(req.user);
    return this.svc.createClassLevel({
      ...body,
      tenantId: scope.tenantId,
      schoolId: scope.schoolId,
    });
  }

  @Patch('class-levels/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  updateClassLevel(
    @Request() req: { user: User },
    @Param('id') id: string,
    @Body() body: Partial<ClassLevel>,
  ) {
    const scope = requireSchoolScope(req.user);
    return this.svc.updateClassLevel(scope.tenantId, scope.schoolId, id, body);
  }

  @Delete('class-levels/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  removeClassLevel(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.removeClassLevel(scope.tenantId, scope.schoolId, id);
  }

  @Get('class-arms')
  @Roles(UserRole.Admin, UserRole.Teacher, UserRole.SupportAdmin, UserRole.SupportTechnician)
  getClassArms(@Request() req: { user: User }, @Query('levelId') levelId?: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.getClassArms(scope.tenantId, scope.schoolId, levelId);
  }

  @Post('class-arms')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  createClassArm(@Request() req: { user: User }, @Body() body: Partial<ClassArm>) {
    const scope = requireSchoolScope(req.user);
    return this.svc.createClassArm({
      ...body,
      tenantId: scope.tenantId,
      schoolId: scope.schoolId,
    });
  }

  @Patch('class-arms/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  updateClassArm(@Request() req: { user: User }, @Param('id') id: string, @Body() body: Partial<ClassArm>) {
    const scope = requireSchoolScope(req.user);
    return this.svc.updateClassArm(scope.tenantId, scope.schoolId, id, body);
  }

  @Delete('class-arms/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  removeClassArm(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.removeClassArm(scope.tenantId, scope.schoolId, id);
  }

  @Get('subjects')
  @Roles(UserRole.Admin, UserRole.Teacher, UserRole.SupportAdmin, UserRole.SupportTechnician)
  getSubjects(@Request() req: { user: User }) {
    const scope = requireSchoolScope(req.user);
    return this.svc.getSubjects(scope.tenantId, scope.schoolId);
  }

  @Post('subjects')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  createSubject(@Request() req: { user: User }, @Body() body: Partial<Subject>) {
    const scope = requireSchoolScope(req.user);
    return this.svc.createSubject({
      ...body,
      tenantId: scope.tenantId,
      schoolId: scope.schoolId,
    });
  }

  @Patch('subjects/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  updateSubject(@Request() req: { user: User }, @Param('id') id: string, @Body() body: Partial<Subject>) {
    const scope = requireSchoolScope(req.user);
    return this.svc.updateSubject(scope.tenantId, scope.schoolId, id, body);
  }

  @Delete('subjects/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  removeSubject(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.removeSubject(scope.tenantId, scope.schoolId, id);
  }

  @Get('grading-schemes')
  @Roles(UserRole.Admin, UserRole.Teacher, UserRole.SupportAdmin, UserRole.SupportTechnician)
  getGradingSchemes(@Request() req: { user: User }) {
    const scope = requireSchoolScope(req.user);
    return this.svc.getGradingSchemes(scope.tenantId, scope.schoolId);
  }

  @Post('grading-schemes')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  createGradingScheme(@Request() req: { user: User }, @Body() body: Partial<GradingScheme>) {
    const scope = requireSchoolScope(req.user);
    return this.svc.createGradingScheme({
      ...body,
      tenantId: scope.tenantId,
      schoolId: scope.schoolId,
    });
  }

  @Patch('grading-schemes/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  updateGradingScheme(
    @Request() req: { user: User },
    @Param('id') id: string,
    @Body() body: Partial<GradingScheme>,
  ) {
    const scope = requireSchoolScope(req.user);
    return this.svc.updateGradingScheme(scope.tenantId, scope.schoolId, id, body);
  }

  @Delete('grading-schemes/:id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  removeGradingScheme(@Request() req: { user: User }, @Param('id') id: string) {
    const scope = requireSchoolScope(req.user);
    return this.svc.removeGradingScheme(scope.tenantId, scope.schoolId, id);
  }
}
