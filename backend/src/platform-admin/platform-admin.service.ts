import { Injectable } from "@nestjs/common";
import type {
  PlatformWorkspaceStatus,
  SchoolPlatformSummary,
  TenantPlatformSummary,
} from "../../../packages/contracts/src";
import { DataSource } from "typeorm";

type TenantPlatformSummaryRow = {
  id: string;
  name: string;
  status: string;
  contactEmail: string | null;
  contactPhone: string | null;
  schoolCount: string | number;
  campusCount: string | number;
  registeredCampusCount: string | number;
  updatedAt: Date | string;
};

type SchoolPlatformSummaryRow = {
  id: string;
  tenantId: string;
  tenantName: string;
  tenantStatus: string;
  name: string;
  shortName: string | null;
  schoolType: string;
  region: string | null;
  district: string | null;
  campusCount: string | number;
  registeredCampusCount: string | number;
  updatedAt: Date | string;
};

@Injectable()
export class PlatformAdminService {
  constructor(private readonly dataSource: DataSource) {}

  async listTenantSummaries(): Promise<TenantPlatformSummary[]> {
    const rows = (await this.dataSource.query(
      `
        SELECT
          t.id AS "id",
          t.name AS "name",
          t.status AS "status",
          t.contact_email AS "contactEmail",
          t.contact_phone AS "contactPhone",
          COUNT(DISTINCT s.id)::int AS "schoolCount",
          COUNT(DISTINCT c.id)::int AS "campusCount",
          COUNT(
            DISTINCT CASE
              WHEN c.registration_code IS NOT NULL AND c.registration_code <> '' THEN c.id
              ELSE NULL
            END
          )::int AS "registeredCampusCount",
          GREATEST(
            t.updated_at,
            COALESCE(MAX(s.updated_at), t.updated_at),
            COALESCE(MAX(c.updated_at), t.updated_at)
          ) AS "updatedAt"
        FROM tenants t
        LEFT JOIN schools s
          ON s.tenant_id = t.id
         AND s.deleted = FALSE
        LEFT JOIN campuses c
          ON c.tenant_id = t.id
         AND c.school_id = s.id
         AND c.deleted = FALSE
        WHERE t.deleted = FALSE
        GROUP BY
          t.id,
          t.name,
          t.status,
          t.contact_email,
          t.contact_phone,
          t.updated_at
        ORDER BY t.name ASC
      `,
    )) as TenantPlatformSummaryRow[];

    return rows.map((row) => this.mapTenantSummary(row));
  }

  async listTenantSchoolSummaries(
    tenantId: string,
  ): Promise<SchoolPlatformSummary[]> {
    const rows = (await this.dataSource.query(
      `
        SELECT
          s.id AS "id",
          s.tenant_id AS "tenantId",
          t.name AS "tenantName",
          t.status AS "tenantStatus",
          s.name AS "name",
          s.short_name AS "shortName",
          s.school_type AS "schoolType",
          s.region AS "region",
          s.district AS "district",
          COUNT(DISTINCT c.id)::int AS "campusCount",
          COUNT(
            DISTINCT CASE
              WHEN c.registration_code IS NOT NULL AND c.registration_code <> '' THEN c.id
              ELSE NULL
            END
          )::int AS "registeredCampusCount",
          GREATEST(s.updated_at, COALESCE(MAX(c.updated_at), s.updated_at)) AS "updatedAt"
        FROM schools s
        INNER JOIN tenants t
          ON t.id = s.tenant_id
         AND t.deleted = FALSE
        LEFT JOIN campuses c
          ON c.tenant_id = s.tenant_id
         AND c.school_id = s.id
         AND c.deleted = FALSE
        WHERE s.deleted = FALSE
          AND s.tenant_id = $1
        GROUP BY
          s.id,
          s.tenant_id,
          t.name,
          t.status,
          s.name,
          s.short_name,
          s.school_type,
          s.region,
          s.district,
          s.updated_at
        ORDER BY s.name ASC
      `,
      [tenantId],
    )) as SchoolPlatformSummaryRow[];

    return rows.map((row) => this.mapSchoolSummary(row));
  }

  private mapTenantSummary(
    row: TenantPlatformSummaryRow,
  ): TenantPlatformSummary {
    const campusCount = Number(row.campusCount);
    const registeredCampusCount = Number(row.registeredCampusCount);

    return {
      id: row.id,
      name: row.name,
      status: row.status,
      contactEmail: row.contactEmail,
      contactPhone: row.contactPhone,
      schoolCount: Number(row.schoolCount),
      campusCount,
      registeredCampusCount,
      workspaceStatus: this.resolveWorkspaceStatus({
        tenantStatus: row.status,
        campusCount,
        registeredCampusCount,
      }),
      updatedAt: new Date(row.updatedAt).toISOString(),
    };
  }

  private mapSchoolSummary(
    row: SchoolPlatformSummaryRow,
  ): SchoolPlatformSummary {
    const campusCount = Number(row.campusCount);
    const registeredCampusCount = Number(row.registeredCampusCount);

    return {
      id: row.id,
      tenantId: row.tenantId,
      tenantName: row.tenantName,
      tenantStatus: row.tenantStatus,
      name: row.name,
      shortName: row.shortName,
      schoolType: row.schoolType,
      region: row.region,
      district: row.district,
      campusCount,
      registeredCampusCount,
      workspaceStatus: this.resolveWorkspaceStatus({
        tenantStatus: row.tenantStatus,
        campusCount,
        registeredCampusCount,
      }),
      updatedAt: new Date(row.updatedAt).toISOString(),
    };
  }

  private resolveWorkspaceStatus(input: {
    tenantStatus: string;
    campusCount: number;
    registeredCampusCount: number;
  }): PlatformWorkspaceStatus {
    if (input.tenantStatus === "suspended") {
      return "attention";
    }
    if (input.campusCount === 0) {
      return "needs_setup";
    }
    if (input.registeredCampusCount < input.campusCount) {
      return "partial_registration";
    }
    return "operational";
  }
}
