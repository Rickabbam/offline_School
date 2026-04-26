import { BadRequestException } from "@nestjs/common";
import { AcademicService } from "./academic.service";

describe("AcademicService", () => {
  let service: AcademicService;
  let dataSource: { query: jest.Mock };
  let years: ReturnType<typeof createRepo>;
  let terms: ReturnType<typeof createRepo>;
  let classLevels: ReturnType<typeof createRepo>;
  let classArms: ReturnType<typeof createRepo>;
  let subjects: ReturnType<typeof createRepo>;
  let gradingSchemes: ReturnType<typeof createRepo>;

  beforeEach(() => {
    dataSource = {
      query: jest.fn(async () => [{ revision: 42 }]),
    };
    years = createRepo();
    terms = createRepo();
    classLevels = createRepo();
    classArms = createRepo();
    subjects = createRepo();
    gradingSchemes = createRepo();

    service = new AcademicService(
      dataSource as never,
      years as never,
      terms as never,
      classLevels as never,
      classArms as never,
      subjects as never,
      gradingSchemes as never,
    );
  });

  it("creates terms only when the academic year belongs to the active scope", async () => {
    years.findOne.mockResolvedValueOnce({
      id: "year-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      deleted: false,
    });

    await service.createTerm({
      id: "client-id",
      tenantId: "tenant-1",
      schoolId: "school-1",
      academicYearId: "year-1",
      name: "Term 1",
      termNumber: 1,
      startDate: "2026-09-01",
      endDate: "2026-12-15",
      isCurrent: true,
      deleted: true,
      serverRevision: 1,
    });

    expect(years.findOne).toHaveBeenCalledWith({
      where: {
        id: "year-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        deleted: false,
      },
    });
    expect(terms.create).toHaveBeenCalledWith({
      tenantId: "tenant-1",
      schoolId: "school-1",
      academicYearId: "year-1",
      name: "Term 1",
      termNumber: 1,
      startDate: "2026-09-01",
      endDate: "2026-12-15",
      isCurrent: true,
      deleted: false,
      serverRevision: 42,
    });
  });

  it("rejects terms whose academic year is outside the active scope", async () => {
    years.findOne.mockResolvedValueOnce(null);

    await expect(
      service.createTerm({
        tenantId: "tenant-1",
        schoolId: "school-1",
        academicYearId: "foreign-year",
        name: "Term 1",
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(terms.save).not.toHaveBeenCalled();
  });

  it("blocks class arms from pointing to a class level outside scope", async () => {
    classLevels.findOne.mockResolvedValueOnce(null);

    await expect(
      service.createClassArm({
        tenantId: "tenant-1",
        schoolId: "school-1",
        classLevelId: "foreign-level",
        arm: "A",
        displayName: "Basic 1 A",
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(classArms.save).not.toHaveBeenCalled();
  });

  it("ignores identity and scope mutation fields on subject update", async () => {
    subjects.findOne
      .mockResolvedValueOnce({
        id: "subject-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        deleted: false,
      })
      .mockResolvedValueOnce({
        id: "subject-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        name: "English",
      });

    await service.updateSubject("tenant-1", "school-1", "subject-1", {
      id: "subject-2",
      tenantId: "tenant-2",
      schoolId: "school-2",
      name: "English",
      code: "ENG",
      deleted: true,
      serverRevision: 1,
    });

    expect(subjects.update).toHaveBeenCalledWith(
      { id: "subject-1", tenantId: "tenant-1", schoolId: "school-1" },
      {
        name: "English",
        code: "ENG",
        serverRevision: 42,
      },
    );
  });

  it("uses trusted school scope when creating academic years", async () => {
    await service.createYear({
      id: "year-client",
      tenantId: "tenant-1",
      schoolId: "school-1",
      label: "2026/2027",
      startDate: "2026-09-01",
      endDate: "2027-07-31",
      isCurrent: true,
      deleted: true,
      serverRevision: 1,
    });

    expect(years.create).toHaveBeenCalledWith({
      tenantId: "tenant-1",
      schoolId: "school-1",
      label: "2026/2027",
      startDate: "2026-09-01",
      endDate: "2027-07-31",
      isCurrent: true,
      deleted: false,
      serverRevision: 42,
    });
  });
});

function createRepo() {
  return {
    find: jest.fn(),
    findOne: jest.fn(),
    create: jest.fn((value) => value),
    save: jest.fn(async (value) => value),
    update: jest.fn(async () => undefined),
  };
}
