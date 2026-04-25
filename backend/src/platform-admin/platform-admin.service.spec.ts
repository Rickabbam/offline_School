import { DataSource } from "typeorm";
import { PlatformAdminService } from "./platform-admin.service";

describe("PlatformAdminService", () => {
  let service: PlatformAdminService;
  let dataSource: { query: jest.Mock };

  beforeEach(() => {
    dataSource = {
      query: jest.fn(),
    };
    service = new PlatformAdminService(dataSource as unknown as DataSource);
  });

  it("returns tenant summaries without operational school records", async () => {
    dataSource.query.mockResolvedValueOnce([
      {
        id: "tenant-1",
        name: "North Ridge Schools",
        status: "active",
        contactEmail: "owner@example.com",
        contactPhone: "2330000000",
        schoolCount: 2,
        campusCount: 3,
        registeredCampusCount: 2,
        updatedAt: "2026-04-23T12:00:00.000Z",
      },
    ]);

    await expect(service.listTenantSummaries()).resolves.toEqual([
      {
        id: "tenant-1",
        name: "North Ridge Schools",
        status: "active",
        contactEmail: "owner@example.com",
        contactPhone: "2330000000",
        schoolCount: 2,
        campusCount: 3,
        registeredCampusCount: 2,
        workspaceStatus: "partial_registration",
        updatedAt: "2026-04-23T12:00:00.000Z",
      },
    ]);
  });

  it("marks suspended tenants as attention even when campuses are registered", async () => {
    dataSource.query.mockResolvedValueOnce([
      {
        id: "tenant-2",
        name: "Suspended Tenant",
        status: "suspended",
        contactEmail: null,
        contactPhone: null,
        schoolCount: 1,
        campusCount: 1,
        registeredCampusCount: 1,
        updatedAt: "2026-04-23T13:00:00.000Z",
      },
    ]);

    const summaries = await service.listTenantSummaries();

    expect(summaries[0].workspaceStatus).toBe("attention");
  });

  it("returns school summaries for one tenant only", async () => {
    dataSource.query.mockResolvedValueOnce([
      {
        id: "school-1",
        tenantId: "tenant-1",
        tenantName: "North Ridge Schools",
        tenantStatus: "trial",
        name: "North Ridge Basic",
        shortName: "NRB",
        schoolType: "basic",
        region: "Greater Accra",
        district: "Ga East",
        campusCount: 0,
        registeredCampusCount: 0,
        updatedAt: "2026-04-23T14:00:00.000Z",
      },
    ]);

    await expect(
      service.listTenantSchoolSummaries("tenant-1"),
    ).resolves.toEqual([
      {
        id: "school-1",
        tenantId: "tenant-1",
        tenantName: "North Ridge Schools",
        tenantStatus: "trial",
        name: "North Ridge Basic",
        shortName: "NRB",
        schoolType: "basic",
        region: "Greater Accra",
        district: "Ga East",
        campusCount: 0,
        registeredCampusCount: 0,
        workspaceStatus: "needs_setup",
        updatedAt: "2026-04-23T14:00:00.000Z",
      },
    ]);

    expect(dataSource.query).toHaveBeenCalledWith(expect.any(String), [
      "tenant-1",
    ]);
  });
});
