import {
  Controller, Get, Post, Patch, Delete, Param, Body, UseGuards, Request,
} from '@nestjs/common';
import { CampusesService } from './campuses.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user-role.enum';
import { Campus } from './campus.entity';
import { User } from '../users/user.entity';

@Controller('campuses')
@UseGuards(JwtAuthGuard, RolesGuard)
export class CampusesController {
  constructor(private readonly svc: CampusesService) {}

  @Get()
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  findAll(@Request() req: { user: User }) {
    return this.svc.findAll(req.user.tenantId!, req.user.schoolId ?? undefined);
  }

  @Get(':id')
  findOne(@Param('id') id: string) { return this.svc.findById(id); }

  @Post()
  @Roles(UserRole.SupportAdmin)
  create(@Body() body: Partial<Campus>) { return this.svc.create(body); }

  @Patch(':id')
  @Roles(UserRole.Admin, UserRole.SupportAdmin)
  update(@Param('id') id: string, @Body() body: Partial<Campus>) {
    return this.svc.update(id, body);
  }

  @Delete(':id')
  @Roles(UserRole.SupportAdmin)
  remove(@Param('id') id: string) { return this.svc.remove(id); }
}
