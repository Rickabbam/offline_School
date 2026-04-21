import {
  Controller, Get, Post, Patch, Delete, Param, Body, UseGuards, Request,
} from '@nestjs/common';
import { SchoolsService } from './schools.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user-role.enum';
import { School } from './school.entity';
import { User } from '../users/user.entity';

@Controller('schools')
@UseGuards(JwtAuthGuard, RolesGuard)
export class SchoolsController {
  constructor(private readonly svc: SchoolsService) {}

  @Get()
  @Roles(UserRole.Admin, UserRole.SupportAdmin)
  findAll(@Request() req: { user: User }) {
    return this.svc.findAll(req.user.tenantId!);
  }

  @Get(':id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin)
  findOne(@Request() req: { user: User }, @Param('id') id: string) {
    return this.svc.findById(req.user.tenantId!, id);
  }

  @Post()
  @Roles(UserRole.SupportAdmin)
  create(@Body() body: Partial<School>) { return this.svc.create(body); }

  @Patch(':id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin)
  update(@Request() req: { user: User }, @Param('id') id: string, @Body() body: Partial<School>) {
    return this.svc.update(req.user.tenantId!, id, body);
  }

  @Delete(':id')
  @Roles(UserRole.SupportAdmin)
  remove(@Request() req: { user: User }, @Param('id') id: string) {
    return this.svc.remove(req.user.tenantId!, id);
  }
}
