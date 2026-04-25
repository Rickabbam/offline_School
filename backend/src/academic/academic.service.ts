import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import {
  AcademicYear,
  ClassArm,
  ClassLevel,
  GradingScheme,
  Subject,
  Term,
} from './academic.entity';

@Injectable()
export class AcademicService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(AcademicYear) private readonly years: Repository<AcademicYear>,
    @InjectRepository(Term) private readonly terms: Repository<Term>,
    @InjectRepository(ClassLevel) private readonly classLevels: Repository<ClassLevel>,
    @InjectRepository(ClassArm) private readonly classArms: Repository<ClassArm>,
    @InjectRepository(Subject) private readonly subjects: Repository<Subject>,
    @InjectRepository(GradingScheme) private readonly gradingSchemes: Repository<GradingScheme>,
  ) {}

  getYears(tenantId: string, schoolId: string) {
    return this.years.find({ where: { tenantId, schoolId, deleted: false } });
  }

  async createYear(data: Partial<AcademicYear>) {
    return this.years.save(
      this.years.create({
        ...data,
        serverRevision: await this.nextServerRevision(),
      }),
    );
  }

  async updateYear(tenantId: string, schoolId: string, id: string, data: Partial<AcademicYear>) {
    const year = await this.years.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!year) throw new NotFoundException('Academic year not found.');
    await this.years.update({ id, tenantId, schoolId }, {
      ...data,
      serverRevision: await this.nextServerRevision(),
    });
    return this.years.findOne({ where: { id, tenantId, schoolId, deleted: false } });
  }

  async removeYear(tenantId: string, schoolId: string, id: string) {
    const year = await this.years.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!year) throw new NotFoundException('Academic year not found.');
    await this.years.update({ id, tenantId, schoolId }, {
      deleted: true,
      serverRevision: await this.nextServerRevision(),
    });
  }

  getTerms(tenantId: string, schoolId: string, yearId?: string) {
    const where: Record<string, unknown> = { tenantId, schoolId, deleted: false };
    if (yearId) where['academicYearId'] = yearId;
    return this.terms.find({ where });
  }

  async createTerm(data: Partial<Term>) {
    return this.terms.save(
      this.terms.create({
        ...data,
        serverRevision: await this.nextServerRevision(),
      }),
    );
  }

  async updateTerm(tenantId: string, schoolId: string, id: string, data: Partial<Term>) {
    const term = await this.terms.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!term) throw new NotFoundException('Term not found.');
    await this.terms.update({ id, tenantId, schoolId }, {
      ...data,
      serverRevision: await this.nextServerRevision(),
    });
    return this.terms.findOne({ where: { id, tenantId, schoolId, deleted: false } });
  }

  async removeTerm(tenantId: string, schoolId: string, id: string) {
    const term = await this.terms.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!term) throw new NotFoundException('Term not found.');
    await this.terms.update({ id, tenantId, schoolId }, {
      deleted: true,
      serverRevision: await this.nextServerRevision(),
    });
  }

  getClassLevels(tenantId: string, schoolId: string) {
    return this.classLevels.find({
      where: { tenantId, schoolId, deleted: false },
      order: { sortOrder: 'ASC' },
    });
  }

  async createClassLevel(data: Partial<ClassLevel>) {
    return this.classLevels.save(
      this.classLevels.create({
        ...data,
        serverRevision: await this.nextServerRevision(),
      }),
    );
  }

  async updateClassLevel(tenantId: string, schoolId: string, id: string, data: Partial<ClassLevel>) {
    const level = await this.classLevels.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!level) throw new NotFoundException('Class level not found.');
    await this.classLevels.update({ id, tenantId, schoolId }, {
      ...data,
      serverRevision: await this.nextServerRevision(),
    });
    return this.classLevels.findOne({ where: { id, tenantId, schoolId, deleted: false } });
  }

  async removeClassLevel(tenantId: string, schoolId: string, id: string) {
    const level = await this.classLevels.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!level) throw new NotFoundException('Class level not found.');
    await this.classLevels.update({ id, tenantId, schoolId }, {
      deleted: true,
      serverRevision: await this.nextServerRevision(),
    });
  }

  getClassArms(tenantId: string, schoolId: string, levelId?: string) {
    const where: Record<string, unknown> = { tenantId, schoolId, deleted: false };
    if (levelId) where['classLevelId'] = levelId;
    return this.classArms.find({ where });
  }

  async createClassArm(data: Partial<ClassArm>) {
    return this.classArms.save(
      this.classArms.create({
        ...data,
        serverRevision: await this.nextServerRevision(),
      }),
    );
  }

  async updateClassArm(tenantId: string, schoolId: string, id: string, data: Partial<ClassArm>) {
    const arm = await this.classArms.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!arm) throw new NotFoundException('Class arm not found.');
    await this.classArms.update({ id, tenantId, schoolId }, {
      ...data,
      serverRevision: await this.nextServerRevision(),
    });
    return this.classArms.findOne({ where: { id, tenantId, schoolId, deleted: false } });
  }

  async removeClassArm(tenantId: string, schoolId: string, id: string) {
    const arm = await this.classArms.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!arm) throw new NotFoundException('Class arm not found.');
    await this.classArms.update({ id, tenantId, schoolId }, {
      deleted: true,
      serverRevision: await this.nextServerRevision(),
    });
  }

  getSubjects(tenantId: string, schoolId: string) {
    return this.subjects.find({ where: { tenantId, schoolId, deleted: false } });
  }

  async createSubject(data: Partial<Subject>) {
    return this.subjects.save(
      this.subjects.create({
        ...data,
        serverRevision: await this.nextServerRevision(),
      }),
    );
  }

  async updateSubject(tenantId: string, schoolId: string, id: string, data: Partial<Subject>) {
    const subject = await this.subjects.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!subject) throw new NotFoundException('Subject not found.');
    await this.subjects.update({ id, tenantId, schoolId }, {
      ...data,
      serverRevision: await this.nextServerRevision(),
    });
    return this.subjects.findOne({ where: { id, tenantId, schoolId, deleted: false } });
  }

  async removeSubject(tenantId: string, schoolId: string, id: string) {
    const subject = await this.subjects.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!subject) throw new NotFoundException('Subject not found.');
    await this.subjects.update({ id, tenantId, schoolId }, {
      deleted: true,
      serverRevision: await this.nextServerRevision(),
    });
  }

  getGradingSchemes(tenantId: string, schoolId: string) {
    return this.gradingSchemes.find({
      where: { tenantId, schoolId, deleted: false },
    });
  }

  async createGradingScheme(data: Partial<GradingScheme>) {
    return this.gradingSchemes.save(
      this.gradingSchemes.create({
        ...data,
        serverRevision: await this.nextServerRevision(),
      }),
    );
  }

  async updateGradingScheme(
    tenantId: string,
    schoolId: string,
    id: string,
    data: Partial<GradingScheme>,
  ) {
    const scheme = await this.gradingSchemes.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!scheme) throw new NotFoundException('Grading scheme not found.');
    await this.gradingSchemes.update(
      { id, tenantId, schoolId },
      {
        ...data,
        serverRevision: await this.nextServerRevision(),
      },
    );
    return this.gradingSchemes.findOne({ where: { id, tenantId, schoolId, deleted: false } });
  }

  async removeGradingScheme(tenantId: string, schoolId: string, id: string) {
    const scheme = await this.gradingSchemes.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!scheme) throw new NotFoundException('Grading scheme not found.');
    await this.gradingSchemes.update(
      { id, tenantId, schoolId },
      {
        deleted: true,
        serverRevision: await this.nextServerRevision(),
      },
    );
  }

  private async nextServerRevision() {
    const result = (await this.dataSource.query(
      "SELECT nextval('sync_server_revision_seq')::bigint AS revision",
    )) as { revision: string | number }[];
    return Number(result[0].revision);
  }
}
