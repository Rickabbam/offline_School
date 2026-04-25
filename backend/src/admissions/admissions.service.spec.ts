import { BadRequestException, NotFoundException } from "@nestjs/common";
import { DataSource, Repository } from "typeorm";
import { AuditService } from "../audit/audit.service";
import { AdmissionsService } from "./admissions.service";
import { Applicant, ApplicantStatus } from "./applicant.entity";
import { AcademicYear, ClassArm } from "../academic/academic.entity";
import {
  Enrollment,
  Guardian,
  GuardianRelationship,
  Student,
  StudentStatus,
} from "../students/student.entity";
import { Campus } from "../campuses/campus.entity";

type MockRepo<T extends object> = Partial<
  Record<keyof Repository<T>, jest.Mock>
>;

describe("AdmissionsService", () => {
  let applicants: MockRepo<Applicant>;
  let students: MockRepo<Student>;
  let guardians: MockRepo<Guardian>;
  let enrollments: MockRepo<Enrollment>;
  let classArms: MockRepo<ClassArm>;
  let academicYears: MockRepo<AcademicYear>;
  let campuses: MockRepo<Campus>;
  let audit: { record: jest.Mock };
  let dataSource: { transaction: jest.Mock; query: jest.Mock };
  let service: AdmissionsService;

  beforeEach(() => {
    applicants = {
      findOne: jest.fn(),
      save: jest.fn(),
      create: jest.fn((value) => value),
      update: jest.fn(),
    };
    students = {
      findOne: jest.fn(),
      save: jest.fn(),
      create: jest.fn((value) => value),
    };
    guardians = {
      save: jest.fn(),
      create: jest.fn((value) => value),
    };
    enrollments = {
      save: jest.fn(),
      create: jest.fn((value) => value),
      findOne: jest.fn(),
    };
    classArms = {
      findOne: jest.fn(),
    };
    academicYears = {
      findOne: jest.fn(),
    };
    campuses = {
      findOne: jest.fn().mockResolvedValue({
        id: 'campus-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        deleted: false,
      } as Campus),
    };
    audit = {
      record: jest.fn(),
    };
    dataSource = {
      transaction: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "10" }]),
    };

    service = new AdmissionsService(
      applicants as unknown as Repository<Applicant>,
      students as unknown as Repository<Student>,
      guardians as unknown as Repository<Guardian>,
      enrollments as unknown as Repository<Enrollment>,
      classArms as unknown as Repository<ClassArm>,
      academicYears as unknown as Repository<AcademicYear>,
      campuses as unknown as Repository<Campus>,
      audit as unknown as AuditService,
      dataSource as unknown as DataSource,
    );
  });

  it("creates applicants in applied status and strips workflow-managed fields", async () => {
    applicants.save!.mockImplementation(async (value) => value);

    await service.create("tenant-1", "school-1", {
      firstName: "Ama",
      lastName: "Mensah",
      campusId: "campus-1",
      guardianName: "Kojo Mensah",
    });

    expect(campuses.findOne).toHaveBeenCalledWith({
      where: {
        id: "campus-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        deleted: false,
      },
    });
    expect(applicants.save).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: "tenant-1",
        schoolId: "school-1",
        status: ApplicantStatus.Applied,
        studentId: null,
        admittedAt: null,
        serverRevision: 10,
        syncStatus: "local",
      }),
    );
  });

  it("rejects applicant creation when campus is outside school scope", async () => {
    campuses.findOne!.mockResolvedValue(null);

    await expect(
      service.create("tenant-1", "school-1", {
        firstName: "Ama",
        lastName: "Mensah",
        campusId: "campus-2",
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(applicants.save).not.toHaveBeenCalled();
  });

  it("enrolls an admitted applicant into student, guardian, and enrollment records", async () => {
    const applicant: Applicant = {
      id: "app-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      campusId: "campus-1",
      firstName: "Ama",
      middleName: null,
      lastName: "Mensah",
      dateOfBirth: "2012-01-12",
      gender: null,
      classLevelId: "level-1",
      academicYearId: "year-1",
      status: ApplicantStatus.Admitted,
      guardianName: "Kojo Mensah",
      guardianPhone: "233555000111",
      guardianEmail: "guardian@example.com",
      documentNotes: "Birth certificate seen",
      studentId: null,
      admittedAt: new Date("2026-04-20T12:00:00.000Z"),
      syncStatus: "synced",
      serverRevision: 1,
      deleted: false,
      createdAt: new Date("2026-04-20T12:00:00.000Z"),
      updatedAt: new Date("2026-04-20T12:00:00.000Z"),
    };
    const academicYear: AcademicYear = {
      id: "year-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      label: "2025/2026",
      startDate: "2025-09-01",
      endDate: "2026-07-31",
      isCurrent: true,
      serverRevision: 2,
      deleted: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    const classArm: ClassArm = {
      id: "arm-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      classLevelId: "level-1",
      arm: "A",
      displayName: "Basic 1A",
      serverRevision: 3,
      deleted: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    applicants.findOne!.mockResolvedValue(applicant);
    academicYears.findOne!.mockResolvedValue(academicYear);
    classArms.findOne!.mockResolvedValue(classArm);

    const manager = {
      create: jest.fn((entity, value) => value),
      save: jest
        .fn()
        .mockImplementationOnce(async (value) => ({ ...value, id: "student-1" }))
        .mockImplementation(async (value) => value),
      update: jest.fn(),
      query: jest
        .fn()
        .mockResolvedValueOnce([{ revision: "11" }])
        .mockResolvedValueOnce([{ revision: "12" }])
        .mockResolvedValueOnce([{ revision: "13" }])
        .mockResolvedValueOnce([{ revision: "14" }]),
    };
    dataSource.transaction.mockImplementation(async (callback) => callback(manager));

    const actor = {
      id: 'user-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
    } as any;

    const result = await service.enroll(actor, "app-1", {
      classArmId: "arm-1",
      academicYearId: "year-1",
      enrollmentDate: "2026-04-22",
    });

    expect(result.student.id).toBe("student-1");
    expect(result.enrollment).toEqual({
      studentId: "student-1",
      classArmId: "arm-1",
      academicYearId: "year-1",
      enrollmentDate: "2026-04-22",
    });

    expect(manager.save).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        firstName: "Ama",
        lastName: "Mensah",
        status: StudentStatus.Active,
        serverRevision: 11,
      }),
    );
    expect(manager.save).toHaveBeenCalledWith(
      expect.objectContaining({
        studentId: "student-1",
        firstName: "Kojo",
        lastName: "Mensah",
        relationship: GuardianRelationship.Guardian,
        isPrimary: true,
        serverRevision: 12,
      }),
    );
    expect(manager.save).toHaveBeenCalledWith(
      expect.objectContaining({
        studentId: "student-1",
        classArmId: "arm-1",
        academicYearId: "year-1",
        enrollmentDate: "2026-04-22",
        serverRevision: 13,
      }),
    );
    expect(manager.update).toHaveBeenCalledWith(
      Applicant,
      "app-1",
      expect.objectContaining({
        status: ApplicantStatus.Enrolled,
        studentId: "student-1",
        academicYearId: "year-1",
        serverRevision: 14,
        syncStatus: "local",
      }),
    );
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        eventType: 'admissions.applicant_enrolled',
        entityType: 'applicant',
        entityId: 'app-1',
      }),
      manager,
    );
  });

  it("audits admitted applicants", async () => {
    const actor = {
      id: 'user-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
    } as any;
    applicants.findOne!.mockResolvedValue({
      id: 'app-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
      status: ApplicantStatus.Applied,
      deleted: false,
    } as Applicant);
    applicants.update!.mockResolvedValue(undefined);
    applicants.findOne!
        .mockResolvedValueOnce({
          id: 'app-1',
          tenantId: 'tenant-1',
          schoolId: 'school-1',
          campusId: 'campus-1',
          status: ApplicantStatus.Applied,
          deleted: false,
        } as Applicant)
        .mockResolvedValueOnce({
          id: 'app-1',
          tenantId: 'tenant-1',
          schoolId: 'school-1',
          campusId: 'campus-1',
          status: ApplicantStatus.Admitted,
          deleted: false,
        } as Applicant);

    await service.admit(actor, 'app-1');

    expect(dataSource.query).toHaveBeenCalledWith(
      "SELECT nextval('sync_server_revision_seq')::bigint AS revision",
    );
    expect(applicants.update).toHaveBeenCalledWith(
      'app-1',
      expect.objectContaining({
        status: ApplicantStatus.Admitted,
        serverRevision: 10,
        syncStatus: 'local',
      }),
    );
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        eventType: 'admissions.applicant_admitted',
        entityType: 'applicant',
        entityId: 'app-1',
      }),
    );
  });

  it("rejects enrollment when the selected class arm does not match the applicant class level", async () => {
    applicants.findOne!.mockResolvedValue({
      id: "app-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      campusId: null,
      firstName: "Ama",
      middleName: null,
      lastName: "Mensah",
      dateOfBirth: null,
      gender: null,
      classLevelId: "level-1",
      academicYearId: "year-1",
      status: ApplicantStatus.Admitted,
      guardianName: null,
      guardianPhone: null,
      guardianEmail: null,
      documentNotes: null,
      studentId: null,
      admittedAt: new Date(),
      syncStatus: "synced",
      serverRevision: 4,
      deleted: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    } as Applicant);
    academicYears.findOne!.mockResolvedValue({
      id: "year-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      label: "2025/2026",
      startDate: "2025-09-01",
      endDate: "2026-07-31",
      isCurrent: true,
      serverRevision: 5,
      deleted: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    } as AcademicYear);
    classArms.findOne!.mockResolvedValue({
      id: "arm-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      classLevelId: "level-2",
      arm: "A",
      displayName: "Basic 2A",
      serverRevision: 6,
      deleted: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    } as ClassArm);

    await expect(
      service.enroll(
        {
          id: 'user-1',
          tenantId: 'tenant-1',
          schoolId: 'school-1',
          campusId: null,
        } as any,
        "app-1",
        {
          classArmId: "arm-1",
          academicYearId: "year-1",
        },
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(dataSource.transaction).not.toHaveBeenCalled();
  });

  it("fails when the applicant does not exist in the active school scope", async () => {
    applicants.findOne!.mockResolvedValue(null);

    await expect(
      service.enroll(
        {
          id: 'user-1',
          tenantId: 'tenant-1',
          schoolId: 'school-1',
          campusId: null,
        } as any,
        "missing",
        {
          classArmId: "arm-1",
        },
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it("replays applicant enrollment safely when the applicant is already linked to a student", async () => {
    applicants.findOne!.mockResolvedValue({
      id: "app-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      campusId: "campus-1",
      firstName: "Ama",
      middleName: null,
      lastName: "Mensah",
      dateOfBirth: null,
      gender: null,
      classLevelId: "level-1",
      academicYearId: "year-1",
      status: ApplicantStatus.Enrolled,
      guardianName: "Kojo Mensah",
      guardianPhone: null,
      guardianEmail: null,
      documentNotes: null,
      studentId: "student-1",
      admittedAt: new Date(),
      syncStatus: "synced",
      serverRevision: 5,
      deleted: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    } as Applicant);
    students.findOne!.mockResolvedValue({
      id: "student-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      campusId: "campus-1",
      firstName: "Ama",
      middleName: null,
      lastName: "Mensah",
      dateOfBirth: null,
      gender: null,
      status: StudentStatus.Active,
      studentNumber: null,
      profilePhotoUrl: null,
      syncStatus: "synced",
      serverRevision: 6,
      deleted: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    } as Student);
    enrollments.findOne!.mockResolvedValue({
      id: "enrollment-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      studentId: "student-1",
      classArmId: "arm-1",
      academicYearId: "year-1",
      enrollmentDate: "2026-04-22",
      serverRevision: 7,
      deleted: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    } as Enrollment);

    const result = await service.enroll(
      {
        id: "user-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
      } as any,
      "app-1",
      {
        classArmId: "arm-1",
        academicYearId: "year-1",
      },
    );

    expect(result).toEqual({
      applicantId: "app-1",
      student: expect.objectContaining({
        id: "student-1",
      }),
      enrollment: {
        studentId: "student-1",
        classArmId: "arm-1",
        academicYearId: "year-1",
        enrollmentDate: "2026-04-22",
      },
    });
    expect(dataSource.transaction).not.toHaveBeenCalled();
    expect(audit.record).not.toHaveBeenCalled();
  });
});
