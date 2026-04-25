import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, IsNull, Repository } from 'typeorm';
import { AcademicYear, ClassArm, Term } from '../academic/academic.entity';
import { Student } from '../students/student.entity';
import { AttendanceRecord, AttendanceStatus } from './attendance-record.entity';

@Injectable()
export class AttendanceService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(AttendanceRecord)
    private readonly repo: Repository<AttendanceRecord>,
    @InjectRepository(Student)
    private readonly students: Repository<Student>,
    @InjectRepository(ClassArm)
    private readonly classArms: Repository<ClassArm>,
    @InjectRepository(AcademicYear)
    private readonly academicYears: Repository<AcademicYear>,
    @InjectRepository(Term)
    private readonly terms: Repository<Term>,
  ) {}

  findByDate(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    classArmId: string,
    date: string,
  ) {
    const where: Record<string, unknown> = {
      tenantId,
      schoolId,
      classArmId,
      attendanceDate: date,
      deleted: false,
      campusId: campusId ?? IsNull(),
    };
    return this.repo.find({
      where,
    });
  }

  findByStudent(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    studentId: string,
    termId?: string,
  ) {
    const where: Record<string, unknown> = {
      tenantId,
      schoolId,
      campusId: campusId ?? IsNull(),
      studentId,
      deleted: false,
    };
    if (termId) where['termId'] = termId;
    return this.repo.find({ where });
  }

  /**
   * Upsert a daily attendance record for a single student.
   * Uses (student_id, class_arm_id, attendance_date) as natural key.
   */
  async upsert(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    data: Partial<AttendanceRecord>,
  ) {
    await this.assertReferencesInScope(tenantId, schoolId, campusId, data);

    const existingWhere: Record<string, unknown> = {
      tenantId,
      schoolId,
      campusId: campusId ?? IsNull(),
      studentId: data.studentId,
      classArmId: data.classArmId,
      attendanceDate: data.attendanceDate,
      deleted: false,
    };
    const existing = await this.repo.findOne({
      where: existingWhere,
    });

    if (existing) {
      await this.repo.update(
        {
          id: existing.id,
          tenantId,
          schoolId,
        },
        {
        status: data.status,
        notes: data.notes,
        recordedByUserId: data.recordedByUserId,
        serverRevision: await this.nextServerRevision(),
        syncStatus: 'local',
        },
      );
      return this.repo.findOne({
        where: { id: existing.id, tenantId, schoolId, deleted: false },
      });
    }

    return this.repo.save(
      this.repo.create({
        ...data,
        tenantId,
        schoolId,
        campusId,
        serverRevision: await this.nextServerRevision(),
        syncStatus: 'local',
      }),
    );
  }

  /**
   * Bulk upsert: record attendance for an entire class at once.
   */
  async bulkUpsert(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    records: Partial<AttendanceRecord>[],
  ) {
    return Promise.all(
      records.map((r) => this.upsert(tenantId, schoolId, campusId, r)),
    );
  }

  /**
   * Summary: count by status for a class arm within a term.
   */
  async summary(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    classArmId: string,
    termId: string,
  ) {
    const query = this.repo
      .createQueryBuilder('a')
      .select('a.student_id', 'studentId')
      .addSelect('a.status', 'status')
      .addSelect('COUNT(*)', 'count')
      .where('a.tenant_id = :tenantId', { tenantId })
      .andWhere('a.school_id = :schoolId', { schoolId })
      .andWhere('a.class_arm_id = :classArmId', { classArmId })
      .andWhere('a.term_id = :termId', { termId })
      .andWhere('a.deleted = false')
      .groupBy('a.student_id')
      .addGroupBy('a.status');
    if (campusId != null) {
      query.andWhere('a.campus_id = :campusId', { campusId });
    }

    const rows = await query.getRawMany();

    return rows;
  }

  private async assertReferencesInScope(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    data: Partial<AttendanceRecord>,
  ) {
    await Promise.all([
      this.assertStudentInScope(
        this.students,
        data.studentId,
        tenantId,
        schoolId,
        campusId,
        'Student not found.',
      ),
      this.assertReferenceInScope(
        this.classArms,
        data.classArmId,
        tenantId,
        schoolId,
        'Class arm not found.',
      ),
      this.assertReferenceInScope(
        this.academicYears,
        data.academicYearId,
        tenantId,
        schoolId,
        'Academic year not found.',
      ),
      this.assertReferenceInScope(
        this.terms,
        data.termId,
        tenantId,
        schoolId,
        'Term not found.',
      ),
    ]);
  }

  private async assertReferenceInScope<T extends { id: string }>(
    repository: Repository<T>,
    id: string | undefined,
    tenantId: string,
    schoolId: string,
    message: string,
  ) {
    if (!id) {
      throw new NotFoundException(message);
    }

    const row = await repository.findOne({
      where: { id, tenantId, schoolId, deleted: false } as never,
    });
    if (!row) {
      throw new NotFoundException(message);
    }
  }

  private async assertStudentInScope(
    repository: Repository<Student>,
    id: string | undefined,
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    message: string,
  ) {
    if (!id) {
      throw new NotFoundException(message);
    }

    const where: Record<string, unknown> = {
      id,
      tenantId,
      schoolId,
      deleted: false,
    };
    if (campusId != null) {
      where['campusId'] = campusId;
    }

    const row = await repository.findOne({
      where: where as never,
    });
    if (!row) {
      throw new NotFoundException(message);
    }
  }

  private async nextServerRevision() {
    const result = (await this.dataSource.query(
      "SELECT nextval('sync_server_revision_seq')::bigint AS revision",
    )) as { revision: string | number }[];
    return Number(result[0].revision);
  }
}
