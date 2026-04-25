export type PlatformWorkspaceStatus =
  | "needs_setup"
  | "partial_registration"
  | "operational"
  | "attention";

export interface TenantPlatformSummary {
  id: string;
  name: string;
  status: string;
  contactEmail: string | null;
  contactPhone: string | null;
  schoolCount: number;
  campusCount: number;
  registeredCampusCount: number;
  workspaceStatus: PlatformWorkspaceStatus;
  updatedAt: string;
}

export interface SchoolPlatformSummary {
  id: string;
  tenantId: string;
  tenantName: string;
  tenantStatus: string;
  name: string;
  shortName: string | null;
  schoolType: string;
  region: string | null;
  district: string | null;
  campusCount: number;
  registeredCampusCount: number;
  workspaceStatus: PlatformWorkspaceStatus;
  updatedAt: string;
}
