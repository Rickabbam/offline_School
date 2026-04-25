import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';
import { AcademicYear, ClassArm } from '../academic/academic.entity';
import { Campus } from '../campuses/campus.entity';
import { Enrollment, Guardian, Student } from './student.entity';
import { StudentsService } from './students.service';

type MockRepo<T extends object> = Partial<
  Record<keyof Repository<T>, jest.Mock>
>;

describe('StudentsService', () => {
  let dataSource: { query: jest.Mock };
  let students: MockRepo<Student>;
  let guardians: MockRepo<Guardian>;
  let enrollments: MockRepo<Enrollment>;
  let academicYears: MockRepo<AcademicYear>;
  let classArms: MockRepo<ClassArm>;
  let campuses: MockRepo<Campus>;
  let service: StudentsService;

  beforeEach(() => {
    dataSource = {
      query: jest.fn().mockResolvedValue([{ revision: '22' }]),
    };
    students = {
      find: jest.fn(),
      findOne: jest.fn(),
      create: jest.fn((value) => value),
      save: jest.fn((value) => Promise.resolve(value)),
      update: jest.fn(),
    };
    guardians = {
      create: jest.fn((value) => value),
      save: jest.fn((value) => Promise.resolve(value)),
    };
    enrollments = {
      create: jest.fn((value) => value),
      findOne: jest.fn(),
      save: jest.fn((value) => Promise.resolve(value)),
    };
    academicYears = {
      findOne: jest.fn().mockResolvedValue({
        id: 'year-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        deleted: false,
      } as AcademicYear),
    };
    classArms = {
      findOne: jest.fn().mockResolvedValue({
        id: 'arm-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        deleted: false,
      } as ClassArm),
    };
    campuses = {
      findOne: jest.fn().mockResolvedValue({
        id: 'campus-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        deleted: false,
      } as Campus),
    };

    service = new StudentsService(
      dataSource as unknown as DataSource,
      students as unknown as Repository<Student>,
      guardians as unknown as Repository<Guardian>,
      enrollments as unknown as Repository<Enrollment>,
      academicYears as unknown as Repository<AcademicYear>,
      classArms as unknown as Repository<ClassArm>,
      campuses as unknown as Repository<Campus>,
    );
  });

  it('rejects student creation when a campus-scoped user targets another campus', async () => {
    await expect(
      service.create('tenant-1', 'school-1', 'campus-1', {
        firstName: 'Ama',
        lastName: 'Mensah',
        campusId: 'campus-2',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);

    expect(dataSource.query).not.toHaveBeenCalled();
    expect(students.findOne).not.toHaveBeenCalled();
  });

  it('creates students only when the campus is in scope', async () => {
    await service.create('tenant-1', 'school-1', 'campus-1', {
      firstName: 'Ama',
      lastName: 'Mensah',
      campusId: 'campus-1',
    });

    expect(campuses.findOne).toHaveBeenCalledWith({
      where: {
        id: 'campus-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        deleted: false,
      },
    });
    expect(students.save).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
        serverRevision: 22,
      }),
    );
  });

  it('filters student searches to the current campus for campus-scoped users', async () => {
    students.find!.mockResolvedValue([]);

    await service.findAll('tenant-1', 'school-1', 'campus-1', 'Ama');

    expect(students.find).toHaveBeenCalledWith({
      where: [
        expect.objectContaining({
          tenantId: 'tenant-1',
          schoolId: 'school-1',
          campusId: 'campus-1',
          deleted: false,
          firstName: expect.anything(),
        }),
        expect.objectContaining({
          tenantId: 'tenant-1',
          schoolId: 'school-1',
          campusId: 'campus-1',
          deleted: false,
          lastName: expect.anything(),
        }),
        expect.objectContaining({
          tenantId: 'tenant-1',
          schoolId: 'school-1',
          campusId: 'campus-1',
          deleted: false,
          studentNumber: expect.anything(),
        }),
      ],
    });
  });

  it('rejects updates for students outside the current campus scope', async () => {
    students.findOne!.mockResolvedValue(null);

    await expect(
      service.update('tenant-1', 'school-1', 'campus-1', 'student-2', {
        firstName: 'Ama',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(students.update).not.toHaveBeenCalled();
    expect(dataSource.query).not.toHaveBeenCalled();
  });

  it('rejects guardian creation when the parent student is outside scope', async () => {
    students.findOne!.mockResolvedValue(null);

    await expect(
      service.addGuardian('tenant-1', 'school-1', 'campus-1', {
        studentId: 'student-2',
        firstName: 'Kojo',
        lastName: 'Mensah',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(guardians.save).not.toHaveBeenCalled();
    expect(dataSource.query).not.toHaveBeenCalled();
  });

  it('creates guardians only for students inside the authenticated scope', async () => {
    students.findOne!.mockResolvedValue({
      id: 'student-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
      deleted: false,
    } as Student);

    await service.addGuardian('tenant-1', 'school-1', 'campus-1', {
      studentId: 'student-1',
      firstName: 'Kojo',
      lastName: 'Mensah',
    });

    expect(students.findOne).toHaveBeenCalledWith({
      where: {
        id: 'student-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
        deleted: false,
      },
    });
    expect(guardians.save).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        studentId: 'student-1',
        serverRevision: 22,
      }),
    );
  });

  it('rejects guardian reads when the student belongs to another campus', async () => {
    students.findOne!.mockResolvedValue(null);

    await expect(
      service.getGuardians('tenant-1', 'school-1', 'campus-1', 'student-2'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('rejects enrollment when the parent student is outside scope', async () => {
    students.findOne!.mockResolvedValue(null);

    await expect(
      service.enroll('tenant-1', 'school-1', 'campus-1', {
        studentId: 'student-2',
        academicYearId: 'year-1',
        classArmId: 'arm-1',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(enrollments.save).not.toHaveBeenCalled();
    expect(dataSource.query).not.toHaveBeenCalled();
  });

  it('rejects enrollment when the academic year is outside scope', async () => {
    students.findOne!.mockResolvedValue({
      id: 'student-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
      deleted: false,
    } as Student);
    academicYears.findOne!.mockResolvedValue(null);

    await expect(
      service.enroll('tenant-1', 'school-1', 'campus-1', {
        studentId: 'student-1',
        academicYearId: 'year-2',
        classArmId: 'arm-1',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(enrollments.save).not.toHaveBeenCalled();
    expect(dataSource.query).not.toHaveBeenCalled();
  });

  it('rejects enrollment when the class arm is outside scope', async () => {
    students.findOne!.mockResolvedValue({
      id: 'student-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
      deleted: false,
    } as Student);
    classArms.findOne!.mockResolvedValue(null);

    await expect(
      service.enroll('tenant-1', 'school-1', 'campus-1', {
        studentId: 'student-1',
        academicYearId: 'year-1',
        classArmId: 'arm-2',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(enrollments.save).not.toHaveBeenCalled();
    expect(dataSource.query).not.toHaveBeenCalled();
  });

  it('creates enrollment only when student, academic year, and class arm are in scope', async () => {
    students.findOne!.mockResolvedValue({
      id: 'student-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
      deleted: false,
    } as Student);
    enrollments.findOne!.mockResolvedValue(null);

    await service.enroll('tenant-1', 'school-1', 'campus-1', {
      studentId: 'student-1',
      academicYearId: 'year-1',
      classArmId: 'arm-1',
    });

    expect(academicYears.findOne).toHaveBeenCalledWith({
      where: {
        id: 'year-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        deleted: false,
      },
    });
    expect(enrollments.save).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        studentId: 'student-1',
        academicYearId: 'year-1',
        classArmId: 'arm-1',
        serverRevision: 22,
      }),
    );
  });
});
