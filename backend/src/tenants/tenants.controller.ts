import {
  Controller, Get, Post, Patch, Delete, Param, Body, UseGuards, Request,
} from '@nestjs/common';
import { TenantsService } from './tenants.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user-role.enum';
import { Tenant } from './tenant.entity';
import { requireTenantScope } from '../auth/request-scope';
import { User } from '../users/user.entity';

@Controller('tenants')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.SupportAdmin)
export class TenantsController {
  constructor(private readonly svc: TenantsService) {}

  @Get()
  findAll() { return this.svc.findAll(); }

  @Get('current')
  @Roles(
    UserRole.Admin,
    UserRole.Cashier,
    UserRole.Teacher,
    UserRole.Parent,
    UserRole.Student,
    UserRole.SupportAdmin,
    UserRole.SupportTechnician,
  )
  findCurrent(@Request() req: { user: User }) {
    const scope = requireTenantScope(req.user);
    return this.svc.findScopedTenant(scope.tenantId);
  }

  @Get(':id')
  findOne(@Param('id') id: string) { return this.svc.findById(id); }

  @Post()
  create(@Body() body: Partial<Tenant>) { return this.svc.create(body); }

  @Patch(':id')
  update(@Param('id') id: string, @Body() body: Partial<Tenant>) {
    return this.svc.update(id, body);
  }

  @Delete(':id')
  remove(@Param('id') id: string) { return this.svc.remove(id); }
}
