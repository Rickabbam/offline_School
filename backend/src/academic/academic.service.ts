import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  AcademicYear,
  Term,
  ClassLevel,
  ClassArm,
  Subject,
  GradingScheme,
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

  // ─── Academic Years ─────────────────────────────────────────────────────────
  getYears(schoolId: string) { return this.years.find({ where: { schoolId, deleted: false } }); }
  createYear(d: Partial<AcademicYear>) { return this.years.save(this.years.create(d)); }
  async updateYear(id: string, d: Partial<AcademicYear>) {
    await this.years.update(id, d);
    return this.years.findOne({ where: { id } });
  }

  // ─── Terms ──────────────────────────────────────────────────────────────────
  getTerms(schoolId: string, yearId?: string) {
    const where: Record<string, unknown> = { schoolId, deleted: false };
    if (yearId) where['academicYearId'] = yearId;
    return this.terms.find({ where });
  }
  createTerm(d: Partial<Term>) { return this.terms.save(this.terms.create(d)); }

  // ─── Class Levels ───────────────────────────────────────────────────────────
  getClassLevels(schoolId: string) {
    return this.classLevels.find({ where: { schoolId, deleted: false }, order: { sortOrder: 'ASC' } });
  }
  createClassLevel(d: Partial<ClassLevel>) { return this.classLevels.save(this.classLevels.create(d)); }

  // ─── Class Arms ─────────────────────────────────────────────────────────────
  getClassArms(schoolId: string, levelId?: string) {
    const where: Record<string, unknown> = { schoolId, deleted: false };
    if (levelId) where['classLevelId'] = levelId;
    return this.classArms.find({ where });
  }
  createClassArm(d: Partial<ClassArm>) { return this.classArms.save(this.classArms.create(d)); }

  // ─── Subjects ───────────────────────────────────────────────────────────────
  getSubjects(schoolId: string) { return this.subjects.find({ where: { schoolId, deleted: false } }); }
  createSubject(d: Partial<Subject>) { return this.subjects.save(this.subjects.create(d)); }

  // ─── Grading Schemes ────────────────────────────────────────────────────────
  getGradingSchemes(schoolId: string) {
    return this.gradingSchemes.find({ where: { schoolId, deleted: false } });
  }
  createGradingScheme(d: Partial<GradingScheme>) {
    return this.gradingSchemes.save(this.gradingSchemes.create(d));
  }
}
