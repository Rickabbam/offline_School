import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Applicant, ApplicantStatus } from './applicant.entity';
import { Student } from '../students/student.entity';

@Injectable()
export class AdmissionsService {
  constructor(
    @InjectRepository(Applicant) private readonly applicants: Repository<Applicant>,
    @InjectRepository(Student) private readonly students: Repository<Student>,
    private readonly dataSource: DataSource,
  ) {}

  findAll(tenantId: string, schoolId: string, status?: ApplicantStatus) {
    const where: Record<string, unknown> = { tenantId, schoolId, deleted: false };
    if (status) where['status'] = status;
    return this.applicants.find({ where });
  }

  findById(id: string) {
    return this.applicants.findOne({ where: { id, deleted: false } });
  }

  create(tenantId: string, schoolId: string, data: Partial<Applicant>) {
    return this.applicants.save(
      this.applicants.create({ ...data, tenantId, schoolId, syncStatus: 'local' }),
    );
  }

  async update(id: string, data: Partial<Applicant>) {
    const app = await this.applicants.findOne({ where: { id } });
    if (!app) throw new NotFoundException('Applicant not found.');
    await this.applicants.update(id, data);
    return this.findById(id);
  }

  /**
   * Admit: move applicant status to 'admitted'.
   */
  async admit(id: string) {
    const app = await this.applicants.findOne({ where: { id, deleted: false } });
    if (!app) throw new NotFoundException('Applicant not found.');
    if (app.status !== ApplicantStatus.Applied && app.status !== ApplicantStatus.Screened) {
      throw new BadRequestException(`Cannot admit applicant in status '${app.status}'.`);
    }
    await this.applicants.update(id, {
      status: ApplicantStatus.Admitted,
      admittedAt: new Date(),
    });
    return this.findById(id);
  }

  /**
   * Enroll: convert admitted applicant to a full Student record (atomic).
   */
  async enroll(id: string) {
    const app = await this.applicants.findOne({ where: { id, deleted: false } });
    if (!app) throw new NotFoundException('Applicant not found.');
    if (app.status !== ApplicantStatus.Admitted) {
      throw new BadRequestException('Applicant must be admitted before enrollment.');
    }

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
        syncStatus: 'local',
      });
      const saved = await manager.save(student);

      await manager.update(Applicant, id, {
        status: ApplicantStatus.Enrolled,
        studentId: saved.id,
      });

      return { student: saved, applicantId: id };
    });
  }

  async reject(id: string) {
    const app = await this.applicants.findOne({ where: { id } });
    if (!app) throw new NotFoundException('Applicant not found.');
    await this.applicants.update(id, { status: ApplicantStatus.Rejected });
    return this.findById(id);
  }
}
