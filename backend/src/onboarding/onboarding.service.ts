import {
  BadRequestException,
  Injectable,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { Tenant, TenantStatus } from '../tenants/tenant.entity';
import { School } from '../schools/school.entity';
import { Campus } from '../campuses/campus.entity';
import {
  AcademicYear,
  ClassArm,
  ClassLevel,
  GradingScheme,
  Subject,
  Term,
} from '../academic/academic.entity';
import { User } from '../users/user.entity';
import { BootstrapSchoolSetupDto } from './dto/bootstrap-school.dto';

@Injectable()
export class OnboardingService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(User) private readonly users: Repository<User>,
  ) {}

  async bootstrapSchoolSetup(currentUserId: string, dto: BootstrapSchoolSetupDto) {
    const currentUser = await this.users.findOne({
      where: { id: currentUserId, deleted: false, isActive: true },
    });

    if (!currentUser) {
      throw new BadRequestException('Authenticated user not found.');
    }

    if (currentUser.tenantId || currentUser.schoolId || currentUser.campusId) {
      throw new BadRequestException('School setup has already been completed for this user.');
    }

    const userId = currentUser.id;

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
          deleted: false,
        }),
      );

      for (const term of dto.academicYear.terms) {
        await manager.save(
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
            deleted: false,
          }),
        );
      }

      for (const levelDto of dto.classLevels) {
        const level = await manager.save(
          ClassLevel,
          manager.create(ClassLevel, {
            tenantId: tenant.id,
            schoolId: school.id,
            name: levelDto.name,
            sortOrder: levelDto.sortOrder,
            deleted: false,
          }),
        );

        for (const armDto of levelDto.arms) {
          await manager.save(
            ClassArm,
            manager.create(ClassArm, {
              tenantId: tenant.id,
              schoolId: school.id,
              classLevelId: level.id,
              arm: armDto.arm,
              displayName: `${levelDto.name} ${armDto.arm}`,
              deleted: false,
            }),
          );
        }
      }

      for (const subjectDto of dto.subjects) {
        await manager.save(
          Subject,
          manager.create(Subject, {
            tenantId: tenant.id,
            schoolId: school.id,
            name: subjectDto.name,
            code: subjectDto.code ?? null,
            deleted: false,
          }),
        );
      }

      await manager.save(
        GradingScheme,
        manager.create(GradingScheme, {
          tenantId: tenant.id,
          schoolId: school.id,
          name: dto.gradingScheme.name,
          bands: dto.gradingScheme.bands,
          isDefault: true,
          deleted: false,
        }),
      );

      await manager.update(User, userId, {
        tenantId: tenant.id,
        schoolId: school.id,
        campusId: campus.id,
      });

      const updatedUser = await manager.findOne(User, {
        where: { id: userId },
      });

      return {
        tenant: {
          id: tenant.id,
          name: tenant.name,
        },
        school: {
          id: school.id,
          name: school.name,
        },
        campus: {
          id: campus.id,
          name: campus.name,
          registrationCode: campus.registrationCode,
        },
        user: updatedUser
            ? {
                id: updatedUser.id,
                email: updatedUser.email,
                fullName: updatedUser.fullName,
                role: updatedUser.role,
                tenantId: updatedUser.tenantId,
                schoolId: updatedUser.schoolId,
                campusId: updatedUser.campusId,
              }
            : null,
      };
    });
  }
}
