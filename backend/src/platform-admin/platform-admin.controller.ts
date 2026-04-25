import { Controller, Get, Param, UseGuards } from "@nestjs/common";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { Roles } from "../auth/roles.decorator";
import { RolesGuard } from "../auth/roles.guard";
import { UserRole } from "../users/user-role.enum";
import { PlatformAdminService } from "./platform-admin.service";

@Controller("platform-admin")
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.SupportAdmin)
export class PlatformAdminController {
  constructor(private readonly platformAdminService: PlatformAdminService) {}

  @Get("tenants")
  listTenantSummaries() {
    return this.platformAdminService.listTenantSummaries();
  }

  @Get("tenants/:tenantId/schools")
  listTenantSchoolSummaries(@Param("tenantId") tenantId: string) {
    return this.platformAdminService.listTenantSchoolSummaries(tenantId);
  }
}
