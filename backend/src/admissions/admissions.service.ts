import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { AuditService } from '../audit/audit.service';
import { Applicant, ApplicantStatus } from './applicant.entity';
import { AcademicYear, ClassArm } from '../academic/academic.entity';
import { User } from '../users/user.entity';
import {
  Enrollment,
  Guardian,
  GuardianRelationship,
  Student,
  StudentStatus,
} from '../students/student.entity';
import { EnrollApplicantDto } from './dto/enroll-applicant.dto';
import { CreateApplicantDto } from './dto/create-applicant.dto';
import { UpdateApplicantDto } from './dto/update-applicant.dto';
import { Campus } from '../campuses/campus.entity';

@Injectable()
export class AdmissionsService {
  constructor(
    @InjectRepository(Applicant) private readonly applicants: Repository<Applicant>,
    @InjectRepository(Student) private readonly students: Repository<Student>,
    @InjectRepository(Guardian) private readonly guardians: Repository<Guardian>,
    @InjectRepository(Enrollment) private readonly enrollments: Repository<Enrollment>,
    @InjectRepository(ClassArm) private readonly classArms: Repository<ClassArm>,
    @InjectRepository(AcademicYear) private readonly academicYears: Repository<AcademicYear>,
    @InjectRepository(Campus) private readonly campuses: Repository<Campus>,
    private readonly audit: AuditService,
    private readonly dataSource: DataSource,
  ) {}

  findAll(tenantId: string, schoolId: string, status?: ApplicantStatus) {
    const where: Record<string, unknown> = { tenantId, schoolId, deleted: false };
    if (status) where['status'] = status;
    return this.applicants.find({ where });
  }

  findById(tenantId: string, schoolId: string, id: string) {
    return this.applicants.findOne({ where: { id, tenantId, schoolId, deleted: false } });
  }

  async create(tenantId: string, schoolId: string, data: CreateApplicantDto) {
    await this.assertCampusInScope(tenantId, schoolId, data.campusId);
    return this.applicants.save(
      this.applicants.create({
        ...data,
        tenantId,
        schoolId,
        status: ApplicantStatus.Applied,
        studentId: null,
        admittedAt: null,
        serverRevision: await this.nextServerRevision(),
        syncStatus: 'local',
      }),
    );
  }

  async update(tenantId: string, schoolId: string, id: string, data: UpdateApplicantDto) {
    const app = await this.applicants.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!app) throw new NotFoundException('Applicant not found.');
    await this.assertCampusInScope(tenantId, schoolId, data.campusId);
    await this.applicants.update(id, {
      ...data,
      serverRevision: await this.nextServerRevision(),
      syncStatus: 'local',
    });
    return this.findById(tenantId, schoolId, id);
  }

  /**
   * Admit: move applicant status to 'admitted'.
   */
  async admit(actor: User, id: string) {
    const tenantId = actor.tenantId!;
    const schoolId = actor.schoolId!;
    const app = await this.applicants.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!app) throw new NotFoundException('Applicant not found.');
    if (app.status !== ApplicantStatus.Applied && app.status !== ApplicantStatus.Screened) {
      throw new BadRequestException(`Cannot admit applicant in status '${app.status}'.`);
    }
    await this.applicants.update(id, {
      status: ApplicantStatus.Admitted,
      admittedAt: new Date(),
      serverRevision: await this.nextServerRevision(),
      syncStatus: 'local',
    });
    await this.audit.record({
      tenantId,
      schoolId,
      campusId: app.campusId,
      actorUserId: actor.id,
      eventType: 'admissions.applicant_admitted',
      entityType: 'applicant',
      entityId: app.id,
      metadata: {
        previousStatus: app.status,
        newStatus: ApplicantStatus.Admitted,
      },
    });
    return this.findById(tenantId, schoolId, id);
  }

  /**
   * Enroll: convert admitted applicant to a full Student record (atomic).
   */
  async enroll(
    actor: User,
    id: string,
    dto: EnrollApplicantDto,
  ) {
    const tenantId = actor.tenantId!;
    const schoolId = actor.schoolId!;
    const app = await this.applicants.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!app) throw new NotFoundException('Applicant not found.');
    if (app.status !== ApplicantStatus.Admitted) {
      if (app.status === ApplicantStatus.Enrolled && app.studentId) {
        return this.buildEnrollmentReplayResponse(
          tenantId,
          schoolId,
          app,
        );
      }
      throw new BadRequestException('Applicant must be admitted before enrollment.');
    }
    if (app.studentId) {
      return this.buildEnrollmentReplayResponse(tenantId, schoolId, app);
    }

    const academicYearId = dto.academicYearId ?? app.academicYearId;
    if (!academicYearId) {
      throw new BadRequestException('Enrollment requires an academic year.');
    }

    const [academicYear, classArm] = await Promise.all([
      this.academicYears.findOne({
        where: { id: academicYearId, tenantId, schoolId, deleted: false },
      }),
      this.classArms.findOne({
        where: { id: dto.classArmId, tenantId, schoolId, deleted: false },
      }),
    ]);
    if (!academicYear) {
      throw new BadRequestException('Academic year not found for this school.');
    }
    if (!classArm) {
      throw new BadRequestException('Class arm not found for this school.');
    }
    if (app.classLevelId && classArm.classLevelId !== app.classLevelId) {
      throw new BadRequestException(
        'Selected class arm does not match the applicant class level.',
      );
    }

    const enrollmentDate = dto.enrollmentDate ?? this.todayIso();

    return this.dataSource.transaction(async (manager) => {
      const student = manager.create(Student, {
        tenantId: app.tenantId,
        schoolId: app.schoolId,
        campusId: app.campusId,
        firstName: app.firstName,
        middleName: app.middleName,
        lastName: app.lastName,
        dateOfBirth: app.dateOfBirth ?? undefined,
        gender: app.gender,
        status: StudentStatus.Active,
        serverRevision: await this.nextServerRevision(manager),
        syncStatus: 'local',
      });
      const saved = await manager.save(student);

      const guardianName = this.splitGuardianName(app.guardianName);
      if (guardianName) {
        await manager.save(
          manager.create(Guardian, {
            tenantId: app.tenantId,
            schoolId: app.schoolId,
            studentId: saved.id,
            firstName: guardianName.firstName,
            lastName: guardianName.lastName,
            relationship: GuardianRelationship.Guardian,
            phone: app.guardianPhone,
            email: app.guardianEmail,
            isPrimary: true,
            serverRevision: await this.nextServerRevision(manager),
          }),
        );
      }

      await manager.save(
        manager.create(Enrollment, {
          tenantId: app.tenantId,
          schoolId: app.schoolId,
          studentId: saved.id,
          classArmId: classArm.id,
          academicYearId: academicYear.id,
          enrollmentDate,
          serverRevision: await this.nextServerRevision(manager),
        }),
      );

      await manager.update(Applicant, id, {
        status: ApplicantStatus.Enrolled,
        studentId: saved.id,
        academicYearId: academicYear.id,
        serverRevision: await this.nextServerRevision(manager),
        syncStatus: 'local',
      });

      await this.audit.record(
        {
          tenantId,
          schoolId,
          campusId: app.campusId,
          actorUserId: actor.id,
          eventType: 'admissions.applicant_enrolled',
          entityType: 'applicant',
          entityId: app.id,
          metadata: {
            previousStatus: app.status,
            newStatus: ApplicantStatus.Enrolled,
            studentId: saved.id,
            classArmId: classArm.id,
            academicYearId: academicYear.id,
            enrollmentDate,
          },
        },
        manager,
      );

      return {
        applicantId: id,
        student: saved,
        enrollment: {
          studentId: saved.id,
          classArmId: classArm.id,
          academicYearId: academicYear.id,
          enrollmentDate,
        },
      };
    });
  }

  private async buildEnrollmentReplayResponse(
    tenantId: string,
    schoolId: string,
    applicant: Applicant,
  ) {
    const student = await this.students.findOne({
      where: {
        id: applicant.studentId!,
        tenantId,
        schoolId,
        deleted: false,
      },
    });
    if (!student) {
      throw new BadRequestException(
        'Applicant is linked to a missing student record.',
      );
    }

    const enrollment = await this.enrollments.findOne({
      where: {
        tenantId,
        schoolId,
        studentId: student.id,
        deleted: false,
      },
      order: {
        createdAt: 'DESC',
      },
    });
    if (!enrollment) {
      throw new BadRequestException(
        'Applicant is linked to a student without an enrollment record.',
      );
    }

    return {
      applicantId: applicant.id,
      student,
      enrollment: {
        studentId: student.id,
        classArmId: enrollment.classArmId,
        academicYearId: enrollment.academicYearId,
        enrollmentDate: enrollment.enrollmentDate,
      },
    };
  }

  async reject(actor: User, id: string) {
    const tenantId = actor.tenantId!;
    const schoolId = actor.schoolId!;
    const app = await this.applicants.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!app) throw new NotFoundException('Applicant not found.');
    await this.applicants.update(id, {
      status: ApplicantStatus.Rejected,
      serverRevision: await this.nextServerRevision(),
      syncStatus: 'local',
    });
    await this.audit.record({
      tenantId,
      schoolId,
      campusId: app.campusId,
      actorUserId: actor.id,
      eventType: 'admissions.applicant_rejected',
      entityType: 'applicant',
      entityId: app.id,
      metadata: {
        previousStatus: app.status,
        newStatus: ApplicantStatus.Rejected,
      },
    });
    return this.findById(tenantId, schoolId, id);
  }

  private splitGuardianName(fullName: string | null): {
    firstName: string;
    lastName: string;
  } | null {
    const trimmed = fullName?.trim() ?? '';
    if (!trimmed) {
      return null;
    }

    const parts = trimmed.split(/\s+/);
    if (parts.length === 1) {
      return {
        firstName: parts[0],
        lastName: 'Guardian',
      };
    }

    return {
      firstName: parts[0],
      lastName: parts.slice(1).join(' '),
    };
  }

  private todayIso() {
    return new Date().toISOString().slice(0, 10);
  }

  private async assertCampusInScope(
    tenantId: string,
    schoolId: string,
    campusId: string | null | undefined,
  ) {
    if (!campusId) {
      return;
    }

    const campus = await this.campuses.findOne({
      where: { id: campusId, tenantId, schoolId, deleted: false },
    });
    if (!campus) {
      throw new BadRequestException('Campus not found for this school.');
    }
  }

  private async nextServerRevision(queryable: Pick<DataSource, 'query'> = this.dataSource) {
    const result = (await queryable.query(
      "SELECT nextval('sync_server_revision_seq')::bigint AS revision",
    )) as { revision: string | number }[];
    return Number(result[0].revision);
  }
}
