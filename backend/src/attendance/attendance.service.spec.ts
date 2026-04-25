import { NotFoundException } from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';
import { AcademicYear, ClassArm, Term } from '../academic/academic.entity';
import { Student } from '../students/student.entity';
import { AttendanceRecord, AttendanceStatus } from './attendance-record.entity';
import { AttendanceService } from './attendance.service';

type MockRepo<T extends object> = Partial<
  Record<keyof Repository<T>, jest.Mock>
>;

describe('AttendanceService', () => {
  let dataSource: { query: jest.Mock };
  let attendance: MockRepo<AttendanceRecord>;
  let students: MockRepo<Student>;
  let classArms: MockRepo<ClassArm>;
  let academicYears: MockRepo<AcademicYear>;
  let terms: MockRepo<Term>;
  let summaryQueryBuilder: {
    select: jest.Mock;
    addSelect: jest.Mock;
    where: jest.Mock;
    andWhere: jest.Mock;
    groupBy: jest.Mock;
    addGroupBy: jest.Mock;
    getRawMany: jest.Mock;
  };
  let service: AttendanceService;

  beforeEach(() => {
    dataSource = {
      query: jest.fn().mockResolvedValue([{ revision: '44' }]),
    };
    attendance = {
      create: jest.fn((value) => value),
      findOne: jest.fn(),
      save: jest.fn((value) => Promise.resolve(value)),
      update: jest.fn(),
    };
    summaryQueryBuilder = {
      select: jest.fn().mockReturnThis(),
      addSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      groupBy: jest.fn().mockReturnThis(),
      addGroupBy: jest.fn().mockReturnThis(),
      getRawMany: jest.fn().mockResolvedValue([]),
    };
    attendance.createQueryBuilder = jest
      .fn()
      .mockReturnValue(summaryQueryBuilder);
    students = { findOne: jest.fn().mockResolvedValue({ id: 'student-1' }) };
    classArms = { findOne: jest.fn().mockResolvedValue({ id: 'arm-1' }) };
    academicYears = { findOne: jest.fn().mockResolvedValue({ id: 'year-1' }) };
    terms = { findOne: jest.fn().mockResolvedValue({ id: 'term-1' }) };

    service = new AttendanceService(
      dataSource as unknown as DataSource,
      attendance as unknown as Repository<AttendanceRecord>,
      students as unknown as Repository<Student>,
      classArms as unknown as Repository<ClassArm>,
      academicYears as unknown as Repository<AcademicYear>,
      terms as unknown as Repository<Term>,
    );
  });

  it('rejects attendance writes when the student is outside scope', async () => {
    students.findOne!.mockResolvedValue(null);

    await expect(
      service.upsert('tenant-1', 'school-1', 'campus-1', {
        studentId: 'student-2',
        classArmId: 'arm-1',
        academicYearId: 'year-1',
        termId: 'term-1',
        attendanceDate: '2026-04-22',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(attendance.save).not.toHaveBeenCalled();
    expect(attendance.update).not.toHaveBeenCalled();
    expect(dataSource.query).not.toHaveBeenCalled();
  });

  it('rejects attendance writes when the student belongs to another campus', async () => {
    students.findOne!.mockResolvedValue(null);

    await expect(
      service.upsert('tenant-1', 'school-1', 'campus-1', {
        studentId: 'student-1',
        classArmId: 'arm-1',
        academicYearId: 'year-1',
        termId: 'term-1',
        attendanceDate: '2026-04-22',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(students.findOne).toHaveBeenCalledWith({
      where: {
        id: 'student-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
        deleted: false,
      },
    });
    expect(attendance.save).not.toHaveBeenCalled();
    expect(dataSource.query).not.toHaveBeenCalled();
  });

  it('creates attendance only after referenced records are in scope', async () => {
    attendance.findOne!.mockResolvedValue(null);

    await service.upsert('tenant-1', 'school-1', 'campus-1', {
      studentId: 'student-1',
      classArmId: 'arm-1',
      academicYearId: 'year-1',
      termId: 'term-1',
      attendanceDate: '2026-04-22',
      status: AttendanceStatus.Present,
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
    expect(classArms.findOne).toHaveBeenCalledWith({
      where: {
        id: 'arm-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        deleted: false,
      },
    });
    expect(academicYears.findOne).toHaveBeenCalledWith({
      where: {
        id: 'year-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        deleted: false,
      },
    });
    expect(terms.findOne).toHaveBeenCalledWith({
      where: {
        id: 'term-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        deleted: false,
      },
    });
    expect(attendance.save).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
        studentId: 'student-1',
        classArmId: 'arm-1',
        serverRevision: 44,
      }),
    );
  });

  it('looks up existing attendance inside the active campus scope', async () => {
    attendance.findOne!.mockResolvedValue({
      id: 'attendance-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
      deleted: false,
    } as AttendanceRecord);

    await service.upsert('tenant-1', 'school-1', 'campus-1', {
      studentId: 'student-1',
      classArmId: 'arm-1',
      academicYearId: 'year-1',
      termId: 'term-1',
      attendanceDate: '2026-04-22',
      status: AttendanceStatus.Late,
    });

    expect(attendance.findOne).toHaveBeenCalledWith({
      where: {
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
        studentId: 'student-1',
        classArmId: 'arm-1',
        attendanceDate: '2026-04-22',
        deleted: false,
      },
    });
    expect(attendance.update).toHaveBeenCalled();
  });

  it('filters attendance summaries by campus when the user is campus-scoped', async () => {
    await service.summary(
      'tenant-1',
      'school-1',
      'campus-1',
      'arm-1',
      'term-1',
    );

    expect(summaryQueryBuilder.andWhere).toHaveBeenCalledWith(
      'a.campus_id = :campusId',
      { campusId: 'campus-1' },
    );
  });
});
