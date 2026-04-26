import { GUARDS_METADATA } from "@nestjs/common/constants";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { ROLES_KEY } from "../auth/roles.decorator";
import { RolesGuard } from "../auth/roles.guard";
import { UserRole } from "../users/user-role.enum";
import { PlatformAdminController } from "./platform-admin.controller";
import { PlatformAdminService } from "./platform-admin.service";

describe("PlatformAdminController", () => {
  it("restricts platform admin endpoints to authenticated support admins", () => {
    expect(Reflect.getMetadata(ROLES_KEY, PlatformAdminController)).toEqual([
      UserRole.SupportAdmin,
    ]);
    expect(
      Reflect.getMetadata(GUARDS_METADATA, PlatformAdminController),
    ).toEqual([JwtAuthGuard, RolesGuard]);
  });

  it("delegates tenant and school summary reads to the platform service", async () => {
    const service = {
      listTenantSummaries: jest.fn(async () => []),
      listTenantSchoolSummaries: jest.fn(async () => []),
    };
    const controller = new PlatformAdminController(
      service as unknown as PlatformAdminService,
    );

    await expect(controller.listTenantSummaries()).resolves.toEqual([]);
    await expect(
      controller.listTenantSchoolSummaries("tenant-1"),
    ).resolves.toEqual([]);

    expect(service.listTenantSummaries).toHaveBeenCalledTimes(1);
    expect(service.listTenantSchoolSummaries).toHaveBeenCalledWith("tenant-1");
  });
});
