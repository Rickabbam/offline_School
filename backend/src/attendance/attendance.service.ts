import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AttendanceRecord, AttendanceStatus } from './attendance-record.entity';

@Injectable()
export class AttendanceService {
  constructor(
    @InjectRepository(AttendanceRecord)
    private readonly repo: Repository<AttendanceRecord>,
  ) {}

  findByDate(tenantId: string, schoolId: string, classArmId: string, date: string) {
    return this.repo.find({
      where: { tenantId, schoolId, classArmId, attendanceDate: date, deleted: false },
    });
  }

  findByStudent(studentId: string, termId?: string) {
    const where: Record<string, unknown> = { studentId, deleted: false };
    if (termId) where['termId'] = termId;
    return this.repo.find({ where });
  }

  /**
   * Upsert a daily attendance record for a single student.
   * Uses (student_id, class_arm_id, attendance_date) as natural key.
   */
  async upsert(tenantId: string, schoolId: string, data: Partial<AttendanceRecord>) {
    const existing = await this.repo.findOne({
      where: {
        studentId: data.studentId,
        classArmId: data.classArmId,
        attendanceDate: data.attendanceDate,
        deleted: false,
      },
    });

    if (existing) {
      await this.repo.update(existing.id, {
        status: data.status,
        notes: data.notes,
        recordedByUserId: data.recordedByUserId,
        syncStatus: 'local',
      });
      return this.repo.findOne({ where: { id: existing.id } });
    }

    return this.repo.save(
      this.repo.create({ ...data, tenantId, schoolId, syncStatus: 'local' }),
    );
  }

  /**
   * Bulk upsert: record attendance for an entire class at once.
   */
  async bulkUpsert(
    tenantId: string,
    schoolId: string,
    records: Partial<AttendanceRecord>[],
  ) {
    return Promise.all(records.map((r) => this.upsert(tenantId, schoolId, r)));
  }

  /**
   * Summary: count by status for a class arm within a term.
   */
  async summary(schoolId: string, classArmId: string, termId: string) {
    const rows = await this.repo
      .createQueryBuilder('a')
      .select('a.student_id', 'studentId')
      .addSelect('a.status', 'status')
      .addSelect('COUNT(*)', 'count')
      .where('a.school_id = :schoolId', { schoolId })
      .andWhere('a.class_arm_id = :classArmId', { classArmId })
      .andWhere('a.term_id = :termId', { termId })
      .andWhere('a.deleted = false')
      .groupBy('a.student_id')
      .addGroupBy('a.status')
      .getRawMany();

    return rows;
  }
}
