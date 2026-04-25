import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository, ILike } from 'typeorm';
import { AcademicYear, ClassArm } from '../academic/academic.entity';
import { Campus } from '../campuses/campus.entity';
import { Student, Guardian, Enrollment } from './student.entity';
import { CreateStudentDto } from './dto/create-student.dto';

@Injectable()
export class StudentsService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(Student) private readonly students: Repository<Student>,
    @InjectRepository(Guardian) private readonly guardians: Repository<Guardian>,
    @InjectRepository(Enrollment) private readonly enrollments: Repository<Enrollment>,
    @InjectRepository(AcademicYear) private readonly academicYears: Repository<AcademicYear>,
    @InjectRepository(ClassArm) private readonly classArms: Repository<ClassArm>,
    @InjectRepository(Campus) private readonly campuses: Repository<Campus>,
  ) {}

  findAll(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    search?: string,
  ) {
    const scope = this.studentScopeWhere(tenantId, schoolId, campusId);
    if (search) {
      return this.students.find({
        where: [
          { ...scope, firstName: ILike(`%${search}%`) },
          { ...scope, lastName: ILike(`%${search}%`) },
          { ...scope, studentNumber: ILike(`%${search}%`) },
        ],
      });
    }
    return this.students.find({ where: scope });
  }

  findById(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    id: string,
  ) {
    return this.students.findOne({
      where: {
        id,
        ...this.studentScopeWhere(tenantId, schoolId, campusId),
      },
    });
  }

  async create(
    tenantId: string,
    schoolId: string,
    userCampusId: string | null,
    dto: CreateStudentDto,
  ) {
    const campusId = await this.resolveRequestedCampusId(
      tenantId,
      schoolId,
      userCampusId,
      dto.campusId,
    );
    const student = this.students.create({
      ...dto,
      campusId,
      tenantId,
      schoolId,
      serverRevision: await this.nextServerRevision(),
      syncStatus: 'local',
    });
    return this.students.save(student);
  }

  async update(
    tenantId: string,
    schoolId: string,
    userCampusId: string | null,
    id: string,
    data: Partial<Student>,
  ) {
    const student = await this.students.findOne({
      where: {
        id,
        ...this.studentScopeWhere(tenantId, schoolId, userCampusId),
      },
    });
    if (!student) throw new NotFoundException('Student not found.');
    const campusId =
      data.campusId === undefined
        ? student.campusId
        : await this.resolveRequestedCampusId(
            tenantId,
            schoolId,
            userCampusId,
            data.campusId,
          );
    await this.students.update({ id, tenantId, schoolId }, {
      ...data,
      campusId,
      serverRevision: await this.nextServerRevision(),
      syncStatus: 'local',
    });
    return this.findById(tenantId, schoolId, userCampusId, id);
  }

  async remove(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    id: string,
  ) {
    const student = await this.students.findOne({
      where: {
        id,
        ...this.studentScopeWhere(tenantId, schoolId, campusId),
      },
    });
    if (!student) throw new NotFoundException('Student not found.');
    await this.students.update({ id, tenantId, schoolId }, {
      deleted: true,
      serverRevision: await this.nextServerRevision(),
      syncStatus: 'local',
    });
  }

  // ─── Guardians ──────────────────────────────────────────────────────────────
  async getGuardians(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    studentId: string,
  ) {
    await this.assertStudentInScope(tenantId, schoolId, studentId, campusId);
    return this.guardians.find({ where: { tenantId, schoolId, studentId, deleted: false } });
  }

  async addGuardian(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    data: Partial<Guardian>,
  ) {
    await this.assertStudentInScope(tenantId, schoolId, data.studentId, campusId);
    return this.guardians.save(
      this.guardians.create({
        ...data,
        tenantId,
        schoolId,
        serverRevision: await this.nextServerRevision(),
      }),
    );
  }

  // ─── Enrollments ────────────────────────────────────────────────────────────
  async getEnrollments(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    studentId: string,
  ) {
    await this.assertStudentInScope(tenantId, schoolId, studentId, campusId);
    return this.enrollments.find({ where: { tenantId, schoolId, studentId, deleted: false } });
  }

  async enroll(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    data: Partial<Enrollment>,
  ) {
    await this.assertStudentInScope(tenantId, schoolId, data.studentId, campusId);
    await this.assertAcademicYearInScope(tenantId, schoolId, data.academicYearId);
    await this.assertClassArmInScope(tenantId, schoolId, data.classArmId);
    const existing = await this.enrollments.findOne({
      where: {
        tenantId,
        schoolId,
        studentId: data.studentId,
        academicYearId: data.academicYearId,
        deleted: false,
      },
    });

    return this.enrollments.save(
      this.enrollments.create({
        ...data,
        tenantId,
        schoolId,
        id: existing?.id,
        serverRevision: await this.nextServerRevision(),
      }),
    );
  }

  private async assertAcademicYearInScope(
    tenantId: string,
    schoolId: string,
    academicYearId: string | undefined,
  ) {
    if (!academicYearId) {
      throw new NotFoundException('Academic year not found.');
    }

    const academicYear = await this.academicYears.findOne({
      where: { id: academicYearId, tenantId, schoolId, deleted: false },
    });
    if (!academicYear) {
      throw new NotFoundException('Academic year not found.');
    }
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
      throw new NotFoundException('Campus not found.');
    }
  }

  private studentScopeWhere(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
  ) {
    return {
      tenantId,
      schoolId,
      deleted: false,
      ...(campusId ? { campusId } : {}),
    };
  }

  private async assertClassArmInScope(
    tenantId: string,
    schoolId: string,
    classArmId: string | undefined,
  ) {
    if (!classArmId) {
      throw new NotFoundException('Class arm not found.');
    }

    const classArm = await this.classArms.findOne({
      where: { id: classArmId, tenantId, schoolId, deleted: false },
    });
    if (!classArm) {
      throw new NotFoundException('Class arm not found.');
    }
  }

  private async assertStudentInScope(
    tenantId: string,
    schoolId: string,
    studentId: string | undefined,
    campusId?: string | null,
  ) {
    if (!studentId) {
      throw new NotFoundException('Student not found.');
    }

    const student = await this.students.findOne({
      where: {
        id: studentId,
        ...this.studentScopeWhere(tenantId, schoolId, campusId ?? null),
      },
    });
    if (!student) {
      throw new NotFoundException('Student not found.');
    }
  }

  private async resolveRequestedCampusId(
    tenantId: string,
    schoolId: string,
    userCampusId: string | null,
    requestedCampusId: string | null | undefined,
  ) {
    if (userCampusId) {
      if (requestedCampusId && requestedCampusId !== userCampusId) {
        throw new ForbiddenException(
          'Campus-scoped users cannot write records for another campus.',
        );
      }
      await this.assertCampusInScope(tenantId, schoolId, userCampusId);
      return userCampusId;
    }

    await this.assertCampusInScope(tenantId, schoolId, requestedCampusId);
    return requestedCampusId ?? null;
  }

  private async nextServerRevision() {
    const result = (await this.dataSource.query(
      "SELECT nextval('sync_server_revision_seq')::bigint AS revision",
    )) as { revision: string | number }[];
    return Number(result[0].revision);
  }
}
