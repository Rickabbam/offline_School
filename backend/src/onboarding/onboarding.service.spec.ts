import { BadRequestException } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import { getRepositoryToken } from "@nestjs/typeorm";
import * as bcrypt from "bcrypt";
import { DataSource } from "typeorm";
import { OnboardingService } from "./onboarding.service";
import { AuditService } from "../audit/audit.service";
import { BootstrapSchoolSetupDto } from "./dto/bootstrap-school.dto";
import { User } from "../users/user.entity";
import { Device } from "../devices/device.entity";
import { UserRole } from "../users/user-role.enum";
import { Tenant } from "../tenants/tenant.entity";
import { School, SchoolType } from "../schools/school.entity";
import { Campus } from "../campuses/campus.entity";
import {
  AcademicYear,
  ClassArm,
  ClassLevel,
  GradingScheme,
  Subject,
  Term,
} from "../academic/academic.entity";

jest.mock("bcrypt", () => ({
  hash: jest.fn(),
}));

describe("OnboardingService", () => {
  let service: OnboardingService;

  const usersRepo = {
    findOne: jest.fn(),
  };

  const dataSource = {
    transaction: jest.fn(),
  };

  const auditService = {
    record: jest.fn(),
  };

  const draft: BootstrapSchoolSetupDto = {
    school: {
      name: "Pilot School",
      shortName: "PS",
      schoolType: SchoolType.Basic,
      address: "Main Street",
      region: "Greater Accra",
      district: "Accra Metro",
      contactPhone: "0200000000",
      contactEmail: "pilot@example.com",
    },
    campus: {
      name: "Main Campus",
      address: "Main Street",
      contactPhone: "0200000000",
      registrationCode: "MAIN",
    },
    academicYear: {
      label: "2026/2027",
      startDate: "2026-09-01",
      endDate: "2027-07-31",
      terms: [
        {
          name: "Term 1",
          termNumber: 1,
          startDate: "2026-09-01",
          endDate: "2026-12-15",
          isCurrent: true,
        },
      ],
    },
    classLevels: [
      {
        name: "JHS 1",
        sortOrder: 1,
        arms: [{ arm: "A" }],
      },
    ],
    subjects: [
      {
        name: "Mathematics",
        code: "MATH",
      },
    ],
    gradingScheme: {
      name: "Default",
      bands: [
        {
          grade: "A",
          min: 80,
          max: 100,
          remark: "Excellent",
        },
      ],
    },
    onboardingDefaults: {
      staffRoles: [],
      feeCategories: [],
      receiptFormat: {
        receiptPrefix: "RCP",
        nextReceiptNumber: 1,
      },
      notifications: {
        smsEnabled: false,
        paymentReceiptsEnabled: true,
        feeRemindersEnabled: true,
      },
    },
    deviceRegistration: {
      registerOfflineAccess: true,
      deviceName: "Admin Office PC",
      deviceFingerprint: "device-fingerprint",
    },
  };

  const currentUser: User = {
    id: "user-1",
    email: "admin@example.com",
    passwordHash: "hash",
    fullName: "Admin User",
    role: UserRole.Admin,
    tenantId: null,
    schoolId: null,
    campusId: null,
    isActive: true,
    sessionVersion: 1,
    deleted: false,
    createdAt: new Date("2026-01-01T00:00:00.000Z"),
    updatedAt: new Date("2026-01-01T00:00:00.000Z"),
  };

  beforeEach(async () => {
    jest.resetAllMocks();

    const moduleRef = await Test.createTestingModule({
      providers: [
        OnboardingService,
        { provide: DataSource, useValue: dataSource },
        { provide: getRepositoryToken(User), useValue: usersRepo },
        { provide: AuditService, useValue: auditService },
      ],
    }).compile();

    service = moduleRef.get(OnboardingService);
  });

  it("bootstraps the school and provisions the trusted device only after scope exists", async () => {
    usersRepo.findOne.mockResolvedValue(currentUser);
    (bcrypt.hash as jest.Mock).mockResolvedValue("hashed-offline-token");

    const state = {
      user: currentUser,
      device: null as Device | null,
      sequence: 1,
    };

    dataSource.transaction.mockImplementation(async (callback) => {
      const manager = {
        query: jest.fn(async () => [{ revision: state.sequence++ }]),
        create: jest.fn((_entity, value) => ({ ...value })),
        save: jest.fn(async (entity, value) => {
          const now = new Date("2026-04-23T12:00:00.000Z");
          const entityName = entity.name;
          const id =
            value.id ?? `${entityName.toLowerCase()}-${state.sequence++}`;
          const saved = {
            ...value,
            id,
            createdAt: value.createdAt ?? now,
            updatedAt: now,
          };
          if (entity === Device) {
            state.device = saved as Device;
          }
          return saved;
        }),
        update: jest.fn(async (entity, id, values) => {
          if (entity === User && id === currentUser.id) {
            state.user = {
              ...state.user,
              ...values,
            };
          }
        }),
        findOne: jest.fn(async (entity, options) => {
          if (entity === Device) {
            return state.device;
          }
          if (entity === User && options.where.id === currentUser.id) {
            return state.user;
          }
          return null;
        }),
      };

      return callback(manager);
    });

    const result = await service.bootstrapSchoolSetup(currentUser.id, draft);
    expect(result.user).not.toBeNull();
    const updatedUser = result.user!;

    expect(updatedUser).toEqual(
      expect.objectContaining({
        id: currentUser.id,
        tenantId: expect.any(String),
        schoolId: expect.any(String),
        campusId: expect.any(String),
      }),
    );
    expect(result.deviceRegistration).toEqual(
      expect.objectContaining({
        deviceName: "Admin Office PC",
        deviceFingerprint: "device-fingerprint",
        offlineToken: expect.stringContaining("-"),
      }),
    );
    expect(result.bootstrapSnapshot).toEqual(
      expect.objectContaining({
        academicYear: expect.objectContaining({
          serverRevision: expect.any(Number),
        }),
        gradingScheme: expect.objectContaining({
          serverRevision: expect.any(Number),
        }),
      }),
    );
    expect(result.bootstrapSnapshot.terms).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          serverRevision: expect.any(Number),
        }),
      ]),
    );
    expect(result.bootstrapSnapshot.classLevels).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          serverRevision: expect.any(Number),
        }),
      ]),
    );
    expect(result.bootstrapSnapshot.classArms).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          serverRevision: expect.any(Number),
        }),
      ]),
    );
    expect(result.bootstrapSnapshot.subjects).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          serverRevision: expect.any(Number),
        }),
      ]),
    );
    expect(state.device).toEqual(
      expect.objectContaining({
        tenantId: updatedUser.tenantId,
        schoolId: updatedUser.schoolId,
        campusId: updatedUser.campusId,
        registeredByUserId: currentUser.id,
        isActive: true,
      }),
    );
    expect(auditService.record).toHaveBeenCalledWith(
      {
        tenantId: updatedUser.tenantId!,
        schoolId: updatedUser.schoolId!,
        campusId: updatedUser.campusId!,
        actorUserId: currentUser.id,
        eventType: "devices.trusted_device_registered",
        entityType: "device",
        entityId: expect.any(String),
        metadata: {
          deviceName: "Admin Office PC",
          deviceFingerprint: "device-fingerprint",
          mode: "onboarding_registration",
        },
      },
      expect.any(Object),
    );
  });

  it("rejects structurally incomplete onboarding before opening a transaction", async () => {
    const incompleteDraft: BootstrapSchoolSetupDto = {
      ...draft,
      classLevels: [],
    };

    await expect(
      service.bootstrapSchoolSetup(currentUser.id, incompleteDraft),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(usersRepo.findOne).not.toHaveBeenCalled();
    expect(dataSource.transaction).not.toHaveBeenCalled();
  });

  it("rejects invalid academic dates before writing onboarding state", async () => {
    const invalidDraft: BootstrapSchoolSetupDto = {
      ...draft,
      academicYear: {
        ...draft.academicYear,
        startDate: "2026-09-01",
        endDate: "2026-08-31",
      },
    };

    await expect(
      service.bootstrapSchoolSetup(currentUser.id, invalidDraft),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(usersRepo.findOne).not.toHaveBeenCalled();
    expect(dataSource.transaction).not.toHaveBeenCalled();
  });

  it("rejects overlapping grading bands before writing onboarding state", async () => {
    const invalidDraft: BootstrapSchoolSetupDto = {
      ...draft,
      gradingScheme: {
        name: "Overlapping",
        bands: [
          { grade: "A", min: 80, max: 100, remark: "Excellent" },
          { grade: "B", min: 70, max: 80, remark: "Good" },
        ],
      },
    };

    await expect(
      service.bootstrapSchoolSetup(currentUser.id, invalidDraft),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(usersRepo.findOne).not.toHaveBeenCalled();
    expect(dataSource.transaction).not.toHaveBeenCalled();
  });

  it("rejects onboarding trusted-device registration when the active fingerprint belongs to another user", async () => {
    usersRepo.findOne.mockResolvedValue(currentUser);
    (bcrypt.hash as jest.Mock).mockResolvedValue("hashed-offline-token");

    dataSource.transaction.mockImplementation(async (callback) => {
      const manager = {
        query: jest.fn(async () => [{ revision: 1 }]),
        create: jest.fn((_entity, value) => ({ ...value })),
        save: jest.fn(async (entity, value) => ({
          ...value,
          id: value.id ?? `${entity.name.toLowerCase()}-1`,
          createdAt: new Date("2026-04-23T12:00:00.000Z"),
          updatedAt: new Date("2026-04-23T12:00:00.000Z"),
        })),
        update: jest.fn(),
        findOne: jest.fn(async (entity) => {
          if (entity === Device) {
            return {
              id: "device-foreign",
              deviceFingerprint: "device-fingerprint",
              registeredByUserId: "user-2",
              isActive: true,
            };
          }
          if (entity === User) {
            return {
              ...currentUser,
              tenantId: "tenant-1",
              schoolId: "school-1",
              campusId: "campus-1",
            };
          }
          return null;
        }),
      };

      return callback(manager);
    });

    await expect(
      service.bootstrapSchoolSetup(currentUser.id, draft),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it("reassigns a previously revoked onboarding device fingerprint and audits it", async () => {
    usersRepo.findOne.mockResolvedValue(currentUser);
    (bcrypt.hash as jest.Mock).mockResolvedValue("hashed-offline-token");

    dataSource.transaction.mockImplementation(async (callback) => {
      const state = {
        user: currentUser,
        device: {
          id: "device-foreign",
          deviceName: "Old Device",
          deviceFingerprint: "device-fingerprint",
          offlineTokenHash: "old-hash",
          tenantId: "tenant-old",
          schoolId: "school-old",
          campusId: "campus-old",
          registeredByUserId: "user-2",
          isActive: false,
          createdAt: new Date("2026-01-01T00:00:00.000Z"),
          updatedAt: new Date("2026-01-01T00:00:00.000Z"),
        } as Device,
        sequence: 1,
      };

      const manager = {
        query: jest.fn(async () => [{ revision: state.sequence++ }]),
        create: jest.fn((_entity, value) => ({ ...value })),
        save: jest.fn(async (entity, value) => {
          const now = new Date("2026-04-23T12:00:00.000Z");
          const saved = {
            ...value,
            id: value.id ?? `${entity.name.toLowerCase()}-${state.sequence++}`,
            createdAt: value.createdAt ?? now,
            updatedAt: now,
          };
          if (entity === Device) {
            state.device = saved as Device;
          }
          return saved;
        }),
        update: jest.fn(async (entity, id, values) => {
          if (entity === User && id === currentUser.id) {
            state.user = {
              ...state.user,
              ...values,
            };
          }
        }),
        findOne: jest.fn(async (entity, options) => {
          if (entity === Device) {
            return state.device;
          }
          if (entity === User && options.where.id === currentUser.id) {
            return state.user;
          }
          return null;
        }),
      };

      return callback(manager);
    });

    const result = await service.bootstrapSchoolSetup(currentUser.id, draft);

    expect(result.deviceRegistration).toEqual(
      expect.objectContaining({
        deviceId: "device-foreign",
        deviceName: "Admin Office PC",
        deviceFingerprint: "device-fingerprint",
      }),
    );
    expect(auditService.record).toHaveBeenCalledWith(
      {
        tenantId: result.user!.tenantId!,
        schoolId: result.user!.schoolId!,
        campusId: result.user!.campusId!,
        actorUserId: currentUser.id,
        eventType: "devices.trusted_device_registered",
        entityType: "device",
        entityId: "device-foreign",
        metadata: {
          deviceName: "Admin Office PC",
          deviceFingerprint: "device-fingerprint",
          mode: "onboarding_reassigned_after_revoke",
        },
      },
      expect.any(Object),
    );
  });

  it("replays onboarding safely for an already scoped admin and returns the existing workspace snapshot", async () => {
    const scopedUser: User = {
      ...currentUser,
      tenantId: "tenant-1",
      schoolId: "school-1",
      campusId: "campus-1",
    };
    usersRepo.findOne.mockResolvedValue(scopedUser);

    const tenant = {
      id: "tenant-1",
      name: "Pilot School Tenant",
      status: "trial",
      contactEmail: "pilot@example.com",
      contactPhone: "0200000000",
      deleted: false,
      createdAt: new Date("2026-04-20T00:00:00.000Z"),
      updatedAt: new Date("2026-04-20T00:00:00.000Z"),
    };
    const school = {
      id: "school-1",
      tenantId: "tenant-1",
      name: "Pilot School",
      shortName: "PS",
      schoolType: SchoolType.Basic,
      address: "Main Street",
      region: "Greater Accra",
      district: "Accra Metro",
      contactPhone: "0200000000",
      contactEmail: "pilot@example.com",
      onboardingDefaults: draft.onboardingDefaults,
      serverRevision: 11,
      deleted: false,
      createdAt: new Date("2026-04-20T00:00:00.000Z"),
      updatedAt: new Date("2026-04-20T00:00:00.000Z"),
    };
    const campus = {
      id: "campus-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      name: "Main Campus",
      address: "Main Street",
      contactPhone: "0200000000",
      registrationCode: "MAIN",
      serverRevision: 12,
      deleted: false,
      createdAt: new Date("2026-04-20T00:00:00.000Z"),
      updatedAt: new Date("2026-04-20T00:00:00.000Z"),
    };
    const academicYear = {
      id: "year-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      label: "2026/2027",
      startDate: "2026-09-01",
      endDate: "2027-07-31",
      isCurrent: true,
      serverRevision: 13,
      deleted: false,
      createdAt: new Date("2026-04-20T00:00:00.000Z"),
      updatedAt: new Date("2026-04-20T00:00:00.000Z"),
    };
    const term = {
      id: "term-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      academicYearId: "year-1",
      name: "Term 1",
      termNumber: 1,
      startDate: "2026-09-01",
      endDate: "2026-12-15",
      isCurrent: true,
      serverRevision: 14,
      deleted: false,
      createdAt: new Date("2026-04-20T00:00:00.000Z"),
      updatedAt: new Date("2026-04-20T00:00:00.000Z"),
    };
    const classLevel = {
      id: "level-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      name: "JHS 1",
      sortOrder: 1,
      serverRevision: 15,
      deleted: false,
      createdAt: new Date("2026-04-20T00:00:00.000Z"),
      updatedAt: new Date("2026-04-20T00:00:00.000Z"),
    };
    const classArm = {
      id: "arm-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      classLevelId: "level-1",
      arm: "A",
      displayName: "JHS 1 A",
      serverRevision: 16,
      deleted: false,
      createdAt: new Date("2026-04-20T00:00:00.000Z"),
      updatedAt: new Date("2026-04-20T00:00:00.000Z"),
    };
    const subject = {
      id: "subject-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      name: "Mathematics",
      code: "MATH",
      serverRevision: 17,
      deleted: false,
      createdAt: new Date("2026-04-20T00:00:00.000Z"),
      updatedAt: new Date("2026-04-20T00:00:00.000Z"),
    };
    const gradingScheme = {
      id: "scheme-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      name: "Default",
      bands: draft.gradingScheme.bands,
      isDefault: true,
      serverRevision: 18,
      deleted: false,
      createdAt: new Date("2026-04-20T00:00:00.000Z"),
      updatedAt: new Date("2026-04-20T00:00:00.000Z"),
    };

    dataSource.transaction.mockImplementation(async (callback) => {
      const manager = {
        findOne: jest.fn(async (entity, options) => {
          if (entity === Tenant) return tenant;
          if (entity === School) return school;
          if (entity === Campus) return campus;
          if (entity === AcademicYear) return academicYear;
          if (entity === GradingScheme) return gradingScheme;
          return null;
        }),
        find: jest.fn(async (entity) => {
          if (entity === Term) return [term];
          if (entity === ClassLevel) return [classLevel];
          if (entity === ClassArm) return [classArm];
          if (entity === Subject) return [subject];
          return [];
        }),
        save: jest.fn(),
        create: jest.fn((_entity, value) => ({ ...value })),
        query: jest.fn(),
        update: jest.fn(),
      };

      return callback(manager);
    });

    const replayDraft: BootstrapSchoolSetupDto = {
      ...draft,
      deviceRegistration: {
        registerOfflineAccess: false,
        deviceName: "",
        deviceFingerprint: "",
      },
    };

    const result = await service.bootstrapSchoolSetup(
      scopedUser.id,
      replayDraft,
    );

    expect(result.user).toEqual(
      expect.objectContaining({
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
      }),
    );
    expect(result.bootstrapSnapshot.academicYear).toEqual(
      expect.objectContaining({
        id: "year-1",
        serverRevision: 13,
      }),
    );
    expect(result.bootstrapSnapshot.terms).toHaveLength(1);
    expect(result.bootstrapSnapshot.classLevels).toHaveLength(1);
    expect(result.bootstrapSnapshot.classArms).toHaveLength(1);
    expect(result.bootstrapSnapshot.subjects).toHaveLength(1);
    expect(result.bootstrapSnapshot.gradingScheme).toEqual(
      expect.objectContaining({
        id: "scheme-1",
        serverRevision: 18,
      }),
    );
    expect(result.deviceRegistration).toBeNull();
    expect(auditService.record).not.toHaveBeenCalled();
  });
});
