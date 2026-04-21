import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike } from 'typeorm';
import { Student, Guardian, Enrollment } from './student.entity';
import { CreateStudentDto } from './dto/create-student.dto';

@Injectable()
export class StudentsService {
  constructor(
    @InjectRepository(Student) private readonly students: Repository<Student>,
    @InjectRepository(Guardian) private readonly guardians: Repository<Guardian>,
    @InjectRepository(Enrollment) private readonly enrollments: Repository<Enrollment>,
  ) {}

  findAll(tenantId: string, schoolId: string, search?: string) {
    if (search) {
      return this.students.find({
        where: [
          { tenantId, schoolId, deleted: false, firstName: ILike(`%${search}%`) },
          { tenantId, schoolId, deleted: false, lastName: ILike(`%${search}%`) },
          { tenantId, schoolId, deleted: false, studentNumber: ILike(`%${search}%`) },
        ],
      });
    }
    return this.students.find({ where: { tenantId, schoolId, deleted: false } });
  }

  findById(tenantId: string, schoolId: string, id: string) {
    return this.students.findOne({ where: { id, tenantId, schoolId, deleted: false } });
  }

  create(tenantId: string, schoolId: string, dto: CreateStudentDto) {
    const student = this.students.create({ ...dto, tenantId, schoolId, syncStatus: 'local' });
    return this.students.save(student);
  }

  async update(tenantId: string, schoolId: string, id: string, data: Partial<Student>) {
    const student = await this.students.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!student) throw new NotFoundException('Student not found.');
    await this.students.update(id, { ...data, syncStatus: 'local' });
    return this.findById(tenantId, schoolId, id);
  }

  async remove(tenantId: string, schoolId: string, id: string) {
    const student = await this.students.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!student) throw new NotFoundException('Student not found.');
    await this.students.update(id, { deleted: true });
  }

  // ─── Guardians ──────────────────────────────────────────────────────────────
  getGuardians(tenantId: string, schoolId: string, studentId: string) {
    return this.guardians.find({ where: { tenantId, schoolId, studentId, deleted: false } });
  }

  addGuardian(tenantId: string, schoolId: string, data: Partial<Guardian>) {
    return this.guardians.save(this.guardians.create({ ...data, tenantId, schoolId }));
  }

  // ─── Enrollments ────────────────────────────────────────────────────────────
  getEnrollments(tenantId: string, schoolId: string, studentId: string) {
    return this.enrollments.find({ where: { tenantId, schoolId, studentId, deleted: false } });
  }

  enroll(tenantId: string, schoolId: string, data: Partial<Enrollment>) {
    return this.enrollments.save(this.enrollments.create({ ...data, tenantId, schoolId }));
  }
}
