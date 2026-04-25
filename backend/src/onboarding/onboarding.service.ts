import { BadRequestException, Injectable, NotFoundException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { DataSource, EntityManager, Repository } from "typeorm";
import * as bcrypt from "bcrypt";
import { randomUUID } from "crypto";
import { AuditService } from "../audit/audit.service";
import { Tenant, TenantStatus } from "../tenants/tenant.entity";
import { School } from "../schools/school.entity";
import { Campus } from "../campuses/campus.entity";
import {
  AcademicYear,
  ClassArm,
  ClassLevel,
  GradingScheme,
  Subject,
  Term,
} from "../academic/academic.entity";
import { User } from "../users/user.entity";
import { Device } from "../devices/device.entity";
import { BootstrapSchoolSetupDto } from "./dto/bootstrap-school.dto";

@Injectable()
export class OnboardingService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(User) private readonly users: Repository<User>,
    private readonly audit: AuditService,
  ) {}

  async bootstrapSchoolSetup(
    currentUserId: string,
    dto: BootstrapSchoolSetupDto,
  ) {
    const currentUser = await this.users.findOne({
      where: { id: currentUserId, deleted: false, isActive: true },
    });

    if (!currentUser) {
      throw new BadRequestException("Authenticated user not found.");
    }

    if (currentUser.tenantId || currentUser.schoolId || currentUser.campusId) {
      if (!currentUser.tenantId || !currentUser.schoolId || !currentUser.campusId) {
        throw new BadRequestException(
          "School setup is in an invalid partial state for this user.",
        );
      }
      return this.resumeBootstrapSchoolSetup(currentUser, dto);
    }

    const userId = currentUser.id;
    const shouldRegisterTrustedDevice =
      dto.deviceRegistration.registerOfflineAccess;
    if (
      shouldRegisterTrustedDevice &&
      (!dto.deviceRegistration.deviceFingerprint ||
        !dto.deviceRegistration.deviceName)
    ) {
      throw new BadRequestException(
        "Trusted device registration requires a device name and fingerprint.",
      );
    }

    return this.dataSource.transaction(async (manager) => {
      const tenant = await manager.save(
        Tenant,
        manager.create(Tenant, {
          name: dto.school.name,
          status: TenantStatus.Trial,
          contactEmail: dto.school.contactEmail ?? null,
          contactPhone: dto.school.contactPhone ?? null,
          deleted: false,
        }),
      );

      const school = await manager.save(
        School,
        manager.create(School, {
          tenantId: tenant.id,
          name: dto.school.name,
          shortName: dto.school.shortName ?? null,
          schoolType: dto.school.schoolType,
          address: dto.school.address ?? null,
          region: dto.school.region ?? null,
          district: dto.school.district ?? null,
          contactPhone: dto.school.contactPhone ?? null,
          contactEmail: dto.school.contactEmail ?? null,
          onboardingDefaults: {
            staffRoles: dto.onboardingDefaults.staffRoles,
            feeCategories: dto.onboardingDefaults.feeCategories,
            receiptFormat: dto.onboardingDefaults.receiptFormat,
            notifications: dto.onboardingDefaults.notifications,
          },
          serverRevision: await this.nextServerRevision(manager),
          deleted: false,
        }),
      );

      const campus = await manager.save(
        Campus,
        manager.create(Campus, {
          tenantId: tenant.id,
          schoolId: school.id,
          name: dto.campus.name,
          address: dto.campus.address ?? null,
          contactPhone: dto.campus.contactPhone ?? null,
          registrationCode: dto.campus.registrationCode ?? null,
          serverRevision: await this.nextServerRevision(manager),
          deleted: false,
        }),
      );

      const year = await manager.save(
        AcademicYear,
        manager.create(AcademicYear, {
          tenantId: tenant.id,
          schoolId: school.id,
          label: dto.academicYear.label,
          startDate: dto.academicYear.startDate,
          endDate: dto.academicYear.endDate,
          isCurrent: true,
          serverRevision: await this.nextServerRevision(manager),
          deleted: false,
        }),
      );

      const terms: Term[] = [];
      for (const term of dto.academicYear.terms) {
        const savedTerm = await manager.save(
          Term,
          manager.create(Term, {
            tenantId: tenant.id,
            schoolId: school.id,
            academicYearId: year.id,
            name: term.name,
            termNumber: term.termNumber,
            startDate: term.startDate,
            endDate: term.endDate,
            isCurrent: term.isCurrent,
            serverRevision: await this.nextServerRevision(manager),
            deleted: false,
          }),
        );
        terms.push(savedTerm);
      }

      const classLevels: ClassLevel[] = [];
      const classArms: ClassArm[] = [];
      for (const levelDto of dto.classLevels) {
        const level = await manager.save(
          ClassLevel,
          manager.create(ClassLevel, {
            tenantId: tenant.id,
            schoolId: school.id,
            name: levelDto.name,
            sortOrder: levelDto.sortOrder,
            serverRevision: await this.nextServerRevision(manager),
            deleted: false,
          }),
        );
        classLevels.push(level);

        for (const armDto of levelDto.arms) {
          const classArm = await manager.save(
            ClassArm,
            manager.create(ClassArm, {
              tenantId: tenant.id,
              schoolId: school.id,
              classLevelId: level.id,
              arm: armDto.arm,
              displayName: `${levelDto.name} ${armDto.arm}`,
              serverRevision: await this.nextServerRevision(manager),
              deleted: false,
            }),
          );
          classArms.push(classArm);
        }
      }

      const subjects: Subject[] = [];
      for (const subjectDto of dto.subjects) {
        const subject = await manager.save(
          Subject,
          manager.create(Subject, {
            tenantId: tenant.id,
            schoolId: school.id,
            name: subjectDto.name,
            code: subjectDto.code ?? null,
            serverRevision: await this.nextServerRevision(manager),
            deleted: false,
          }),
        );
        subjects.push(subject);
      }

      const gradingScheme = await manager.save(
        GradingScheme,
        manager.create(GradingScheme, {
          tenantId: tenant.id,
          schoolId: school.id,
          name: dto.gradingScheme.name,
          bands: dto.gradingScheme.bands,
          isDefault: true,
          serverRevision: await this.nextServerRevision(manager),
          deleted: false,
        }),
      );

      await manager.update(User, userId, {
        tenantId: tenant.id,
        schoolId: school.id,
        campusId: campus.id,
      });

      const deviceRegistration = shouldRegisterTrustedDevice
        ? await this.registerTrustedDevice(manager, {
            tenantId: tenant.id,
            schoolId: school.id,
            campusId: campus.id,
            userId,
            deviceName: dto.deviceRegistration.deviceName,
            deviceFingerprint: dto.deviceRegistration.deviceFingerprint,
          })
        : null;

      const updatedUser = await manager.findOne(User, {
        where: { id: userId },
      });

      return this.buildBootstrapResponse({
        tenant,
        school,
        campus,
        academicYear: year,
        terms,
        classLevels,
        classArms,
        subjects,
        gradingScheme,
        user: updatedUser,
        deviceRegistration,
      });
    });
  }

  private async resumeBootstrapSchoolSetup(
    currentUser: User,
    dto: BootstrapSchoolSetupDto,
  ) {
    return this.dataSource.transaction(async (manager) => {
      const tenant = await manager.findOne(Tenant, {
        where: { id: currentUser.tenantId!, deleted: false },
      });
      const school = await manager.findOne(School, {
        where: {
          id: currentUser.schoolId!,
          tenantId: currentUser.tenantId!,
          deleted: false,
        },
      });
      const campus = await manager.findOne(Campus, {
        where: {
          id: currentUser.campusId!,
          tenantId: currentUser.tenantId!,
          schoolId: currentUser.schoolId!,
          deleted: false,
        },
      });

      if (!tenant || !school || !campus) {
        throw new NotFoundException(
          "Existing onboarding workspace could not be reconstructed.",
        );
      }

      const academicYear = await manager.findOne(AcademicYear, {
        where: {
          tenantId: currentUser.tenantId!,
          schoolId: currentUser.schoolId!,
          deleted: false,
          isCurrent: true,
        },
        order: {
          updatedAt: "DESC",
        },
      });
      const terms = academicYear
        ? await manager.find(Term, {
            where: {
              tenantId: currentUser.tenantId!,
              schoolId: currentUser.schoolId!,
              academicYearId: academicYear.id,
              deleted: false,
            },
            order: {
              termNumber: "ASC",
            },
          })
        : [];
      const classLevels = await manager.find(ClassLevel, {
        where: {
          tenantId: currentUser.tenantId!,
          schoolId: currentUser.schoolId!,
          deleted: false,
        },
        order: {
          sortOrder: "ASC",
          createdAt: "ASC",
        },
      });
      const classArms = await manager.find(ClassArm, {
        where: {
          tenantId: currentUser.tenantId!,
          schoolId: currentUser.schoolId!,
          deleted: false,
        },
        order: {
          displayName: "ASC",
        },
      });
      const subjects = await manager.find(Subject, {
        where: {
          tenantId: currentUser.tenantId!,
          schoolId: currentUser.schoolId!,
          deleted: false,
        },
        order: {
          name: "ASC",
        },
      });
      const gradingScheme =
        (await manager.findOne(GradingScheme, {
          where: {
            tenantId: currentUser.tenantId!,
            schoolId: currentUser.schoolId!,
            deleted: false,
            isDefault: true,
          },
          order: {
            updatedAt: "DESC",
          },
        })) ??
        (await manager.findOne(GradingScheme, {
          where: {
            tenantId: currentUser.tenantId!,
            schoolId: currentUser.schoolId!,
            deleted: false,
          },
          order: {
            updatedAt: "DESC",
          },
        }));

      const deviceRegistration = dto.deviceRegistration.registerOfflineAccess
        ? await this.registerTrustedDevice(manager, {
            tenantId: tenant.id,
            schoolId: school.id,
            campusId: campus.id,
            userId: currentUser.id,
            deviceName: dto.deviceRegistration.deviceName,
            deviceFingerprint: dto.deviceRegistration.deviceFingerprint,
          })
        : null;

      return this.buildBootstrapResponse({
        tenant,
        school,
        campus,
        academicYear,
        terms,
        classLevels,
        classArms,
        subjects,
        gradingScheme,
        user: currentUser,
        deviceRegistration,
      });
    });
  }

  private async registerTrustedDevice(
    manager: EntityManager,
    input: {
      tenantId: string;
      schoolId: string;
      campusId: string;
      userId: string;
      deviceName: string;
      deviceFingerprint: string;
    },
  ) {
    const rawOfflineToken = `${randomUUID()}-${randomUUID()}`;
    const offlineTokenHash = await bcrypt.hash(rawOfflineToken, 12);
    const existingDevice = await manager.findOne(Device, {
      where: {
        deviceFingerprint: input.deviceFingerprint,
      },
    });

    if (
      existingDevice &&
      existingDevice.registeredByUserId !== input.userId &&
      existingDevice.isActive
    ) {
      throw new BadRequestException(
        "Device fingerprint is already registered to another user.",
      );
    }

    const device = await manager.save(
      Device,
      manager.create(Device, {
        ...(existingDevice ?? {}),
        id: existingDevice?.id,
        deviceName: input.deviceName,
        deviceFingerprint: input.deviceFingerprint,
        offlineTokenHash,
        tenantId: input.tenantId,
        schoolId: input.schoolId,
        campusId: input.campusId,
        registeredByUserId: input.userId,
        isActive: true,
      }),
    );

    await this.audit.record(
      {
        tenantId: input.tenantId,
        schoolId: input.schoolId,
        campusId: input.campusId,
        actorUserId: input.userId,
        eventType: "devices.trusted_device_registered",
        entityType: "device",
        entityId: device.id,
        metadata: {
          deviceName: device.deviceName,
          deviceFingerprint: device.deviceFingerprint,
          mode:
            existingDevice == null
              ? "onboarding_registration"
              : existingDevice.registeredByUserId === input.userId
                ? "onboarding_credential_rotation"
                : "onboarding_reassigned_after_revoke",
        },
      },
      manager,
    );

    return {
      deviceId: device.id,
      deviceName: device.deviceName,
      deviceFingerprint: device.deviceFingerprint,
      offlineToken: rawOfflineToken,
    };
  }

  private buildBootstrapResponse(input: {
    tenant: Tenant;
    school: School;
    campus: Campus;
    academicYear: AcademicYear | null;
    terms: Term[];
    classLevels: ClassLevel[];
    classArms: ClassArm[];
    subjects: Subject[];
    gradingScheme: GradingScheme | null;
    user: User | null;
    deviceRegistration:
      | {
          deviceId: string;
          deviceName: string;
          deviceFingerprint: string;
          offlineToken: string;
        }
      | null;
  }) {
    return {
      tenant: {
        id: input.tenant.id,
        name: input.tenant.name,
        status: input.tenant.status,
        contactEmail: input.tenant.contactEmail,
        contactPhone: input.tenant.contactPhone,
        deleted: input.tenant.deleted,
        createdAt: input.tenant.createdAt.toISOString(),
        updatedAt: input.tenant.updatedAt.toISOString(),
      },
      school: {
        id: input.school.id,
        tenantId: input.school.tenantId,
        name: input.school.name,
        shortName: input.school.shortName,
        schoolType: input.school.schoolType,
        address: input.school.address,
        region: input.school.region,
        district: input.school.district,
        contactPhone: input.school.contactPhone,
        contactEmail: input.school.contactEmail,
        onboardingDefaults: input.school.onboardingDefaults,
        serverRevision: input.school.serverRevision,
        deleted: input.school.deleted,
        createdAt: input.school.createdAt.toISOString(),
        updatedAt: input.school.updatedAt.toISOString(),
      },
      campus: {
        id: input.campus.id,
        tenantId: input.campus.tenantId,
        schoolId: input.campus.schoolId,
        name: input.campus.name,
        address: input.campus.address,
        contactPhone: input.campus.contactPhone,
        registrationCode: input.campus.registrationCode,
        serverRevision: input.campus.serverRevision,
        deleted: input.campus.deleted,
        createdAt: input.campus.createdAt.toISOString(),
        updatedAt: input.campus.updatedAt.toISOString(),
      },
      bootstrapSnapshot: {
        academicYear: input.academicYear
          ? this.serializeEntity(input.academicYear)
          : null,
        terms: input.terms.map((term) => this.serializeEntity(term)),
        classLevels: input.classLevels.map((level) => this.serializeEntity(level)),
        classArms: input.classArms.map((arm) => this.serializeEntity(arm)),
        subjects: input.subjects.map((subject) => this.serializeEntity(subject)),
        gradingScheme: input.gradingScheme
          ? this.serializeEntity(input.gradingScheme)
          : null,
      },
      user: input.user
        ? {
            id: input.user.id,
            email: input.user.email,
            fullName: input.user.fullName,
            role: input.user.role,
            tenantId: input.user.tenantId,
            schoolId: input.user.schoolId,
            campusId: input.user.campusId,
          }
        : null,
      deviceRegistration: input.deviceRegistration,
    };
  }

  private serializeEntity<T extends { createdAt: Date; updatedAt: Date }>(
    entity: T,
  ) {
    return {
      ...entity,
      createdAt: entity.createdAt.toISOString(),
      updatedAt: entity.updatedAt.toISOString(),
    };
  }

  private async nextServerRevision(manager: {
    query: (query: string) => Promise<unknown>;
  }) {
    const result = (await manager.query(
      "SELECT nextval('sync_server_revision_seq')::bigint AS revision",
    )) as { revision: string | number }[];
    return Number(result[0].revision);
  }
}
