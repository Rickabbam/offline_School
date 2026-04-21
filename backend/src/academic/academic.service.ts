import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
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
    @InjectRepository(AcademicYear) private readonly years: Repository<AcademicYear>,
    @InjectRepository(Term) private readonly terms: Repository<Term>,
    @InjectRepository(ClassLevel) private readonly classLevels: Repository<ClassLevel>,
    @InjectRepository(ClassArm) private readonly classArms: Repository<ClassArm>,
    @InjectRepository(Subject) private readonly subjects: Repository<Subject>,
    @InjectRepository(GradingScheme) private readonly gradingSchemes: Repository<GradingScheme>,
  ) {}

  getYears(schoolId: string) {
    return this.years.find({ where: { schoolId, deleted: false } });
  }

  createYear(data: Partial<AcademicYear>) {
    return this.years.save(this.years.create(data));
  }

  async updateYear(tenantId: string, schoolId: string, id: string, data: Partial<AcademicYear>) {
    const year = await this.years.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!year) throw new NotFoundException('Academic year not found.');
    await this.years.update(id, data);
    return this.years.findOne({ where: { id, tenantId, schoolId, deleted: false } });
  }

  async removeYear(tenantId: string, schoolId: string, id: string) {
    const year = await this.years.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!year) throw new NotFoundException('Academic year not found.');
    await this.years.update(id, { deleted: true });
  }

  getTerms(schoolId: string, yearId?: string) {
    const where: Record<string, unknown> = { schoolId, deleted: false };
    if (yearId) where['academicYearId'] = yearId;
    return this.terms.find({ where });
  }

  createTerm(data: Partial<Term>) {
    return this.terms.save(this.terms.create(data));
  }

  async updateTerm(tenantId: string, schoolId: string, id: string, data: Partial<Term>) {
    const term = await this.terms.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!term) throw new NotFoundException('Term not found.');
    await this.terms.update(id, data);
    return this.terms.findOne({ where: { id, tenantId, schoolId, deleted: false } });
  }

  async removeTerm(tenantId: string, schoolId: string, id: string) {
    const term = await this.terms.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!term) throw new NotFoundException('Term not found.');
    await this.terms.update(id, { deleted: true });
  }

  getClassLevels(schoolId: string) {
    return this.classLevels.find({
      where: { schoolId, deleted: false },
      order: { sortOrder: 'ASC' },
    });
  }

  createClassLevel(data: Partial<ClassLevel>) {
    return this.classLevels.save(this.classLevels.create(data));
  }

  async updateClassLevel(tenantId: string, schoolId: string, id: string, data: Partial<ClassLevel>) {
    const level = await this.classLevels.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!level) throw new NotFoundException('Class level not found.');
    await this.classLevels.update(id, data);
    return this.classLevels.findOne({ where: { id, tenantId, schoolId, deleted: false } });
  }

  async removeClassLevel(tenantId: string, schoolId: string, id: string) {
    const level = await this.classLevels.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!level) throw new NotFoundException('Class level not found.');
    await this.classLevels.update(id, { deleted: true });
  }

  getClassArms(schoolId: string, levelId?: string) {
    const where: Record<string, unknown> = { schoolId, deleted: false };
    if (levelId) where['classLevelId'] = levelId;
    return this.classArms.find({ where });
  }

  createClassArm(data: Partial<ClassArm>) {
    return this.classArms.save(this.classArms.create(data));
  }

  async updateClassArm(tenantId: string, schoolId: string, id: string, data: Partial<ClassArm>) {
    const arm = await this.classArms.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!arm) throw new NotFoundException('Class arm not found.');
    await this.classArms.update(id, data);
    return this.classArms.findOne({ where: { id, tenantId, schoolId, deleted: false } });
  }

  async removeClassArm(tenantId: string, schoolId: string, id: string) {
    const arm = await this.classArms.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!arm) throw new NotFoundException('Class arm not found.');
    await this.classArms.update(id, { deleted: true });
  }

  getSubjects(schoolId: string) {
    return this.subjects.find({ where: { schoolId, deleted: false } });
  }

  createSubject(data: Partial<Subject>) {
    return this.subjects.save(this.subjects.create(data));
  }

  async updateSubject(tenantId: string, schoolId: string, id: string, data: Partial<Subject>) {
    const subject = await this.subjects.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!subject) throw new NotFoundException('Subject not found.');
    await this.subjects.update(id, data);
    return this.subjects.findOne({ where: { id, tenantId, schoolId, deleted: false } });
  }

  async removeSubject(tenantId: string, schoolId: string, id: string) {
    const subject = await this.subjects.findOne({ where: { id, tenantId, schoolId, deleted: false } });
    if (!subject) throw new NotFoundException('Subject not found.');
    await this.subjects.update(id, { deleted: true });
  }

  getGradingSchemes(schoolId: string) {
    return this.gradingSchemes.find({ where: { schoolId, deleted: false } });
  }

  createGradingScheme(data: Partial<GradingScheme>) {
    return this.gradingSchemes.save(this.gradingSchemes.create(data));
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
    await this.gradingSchemes.update(id, data);
    return this.gradingSchemes.findOne({ where: { id, tenantId, schoolId, deleted: false } });
  }

  async removeGradingScheme(tenantId: string, schoolId: string, id: string) {
    const scheme = await this.gradingSchemes.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!scheme) throw new NotFoundException('Grading scheme not found.');
    await this.gradingSchemes.update(id, { deleted: true });
  }
}
