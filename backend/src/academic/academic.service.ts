import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { DataSource, Repository } from "typeorm";
import {
  AcademicYear,
  ClassArm,
  ClassLevel,
  GradingScheme,
  Subject,
  Term,
} from "./academic.entity";

@Injectable()
export class AcademicService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(AcademicYear)
    private readonly years: Repository<AcademicYear>,
    @InjectRepository(Term) private readonly terms: Repository<Term>,
    @InjectRepository(ClassLevel)
    private readonly classLevels: Repository<ClassLevel>,
    @InjectRepository(ClassArm)
    private readonly classArms: Repository<ClassArm>,
    @InjectRepository(Subject) private readonly subjects: Repository<Subject>,
    @InjectRepository(GradingScheme)
    private readonly gradingSchemes: Repository<GradingScheme>,
  ) {}

  getYears(tenantId: string, schoolId: string) {
    return this.years.find({ where: { tenantId, schoolId, deleted: false } });
  }

  async createYear(data: Partial<AcademicYear>) {
    const scope = this.requireSchoolScope(data);
    return this.years.save(
      this.years.create({
        ...this.pickDefined(data, [
          "label",
          "startDate",
          "endDate",
          "isCurrent",
        ]),
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        deleted: false,
        serverRevision: await this.nextServerRevision(),
      }),
    );
  }

  async updateYear(
    tenantId: string,
    schoolId: string,
    id: string,
    data: Partial<AcademicYear>,
  ) {
    const year = await this.years.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!year) throw new NotFoundException("Academic year not found.");
    await this.years.update(
      { id, tenantId, schoolId },
      {
        ...this.pickDefined(data, [
          "label",
          "startDate",
          "endDate",
          "isCurrent",
        ]),
        serverRevision: await this.nextServerRevision(),
      },
    );
    return this.years.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
  }

  async removeYear(tenantId: string, schoolId: string, id: string) {
    const year = await this.years.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!year) throw new NotFoundException("Academic year not found.");
    await this.years.update(
      { id, tenantId, schoolId },
      {
        deleted: true,
        serverRevision: await this.nextServerRevision(),
      },
    );
  }

  getTerms(tenantId: string, schoolId: string, yearId?: string) {
    const where: Record<string, unknown> = {
      tenantId,
      schoolId,
      deleted: false,
    };
    if (yearId) where["academicYearId"] = yearId;
    return this.terms.find({ where });
  }

  async createTerm(data: Partial<Term>) {
    const scope = this.requireSchoolScope(data);
    if (!data.academicYearId) {
      throw new BadRequestException("Term requires an academic year.");
    }
    await this.assertAcademicYearInScope(
      scope.tenantId,
      scope.schoolId,
      data.academicYearId,
    );
    return this.terms.save(
      this.terms.create({
        ...this.pickDefined(data, [
          "academicYearId",
          "name",
          "termNumber",
          "startDate",
          "endDate",
          "isCurrent",
        ]),
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        deleted: false,
        serverRevision: await this.nextServerRevision(),
      }),
    );
  }

  async updateTerm(
    tenantId: string,
    schoolId: string,
    id: string,
    data: Partial<Term>,
  ) {
    const term = await this.terms.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!term) throw new NotFoundException("Term not found.");
    if (data.academicYearId) {
      await this.assertAcademicYearInScope(
        tenantId,
        schoolId,
        data.academicYearId,
      );
    }
    await this.terms.update(
      { id, tenantId, schoolId },
      {
        ...this.pickDefined(data, [
          "academicYearId",
          "name",
          "termNumber",
          "startDate",
          "endDate",
          "isCurrent",
        ]),
        serverRevision: await this.nextServerRevision(),
      },
    );
    return this.terms.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
  }

  async removeTerm(tenantId: string, schoolId: string, id: string) {
    const term = await this.terms.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!term) throw new NotFoundException("Term not found.");
    await this.terms.update(
      { id, tenantId, schoolId },
      {
        deleted: true,
        serverRevision: await this.nextServerRevision(),
      },
    );
  }

  getClassLevels(tenantId: string, schoolId: string) {
    return this.classLevels.find({
      where: { tenantId, schoolId, deleted: false },
      order: { sortOrder: "ASC" },
    });
  }

  async createClassLevel(data: Partial<ClassLevel>) {
    const scope = this.requireSchoolScope(data);
    return this.classLevels.save(
      this.classLevels.create({
        ...this.pickDefined(data, ["name", "sortOrder"]),
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        deleted: false,
        serverRevision: await this.nextServerRevision(),
      }),
    );
  }

  async updateClassLevel(
    tenantId: string,
    schoolId: string,
    id: string,
    data: Partial<ClassLevel>,
  ) {
    const level = await this.classLevels.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!level) throw new NotFoundException("Class level not found.");
    await this.classLevels.update(
      { id, tenantId, schoolId },
      {
        ...this.pickDefined(data, ["name", "sortOrder"]),
        serverRevision: await this.nextServerRevision(),
      },
    );
    return this.classLevels.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
  }

  async removeClassLevel(tenantId: string, schoolId: string, id: string) {
    const level = await this.classLevels.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!level) throw new NotFoundException("Class level not found.");
    await this.classLevels.update(
      { id, tenantId, schoolId },
      {
        deleted: true,
        serverRevision: await this.nextServerRevision(),
      },
    );
  }

  getClassArms(tenantId: string, schoolId: string, levelId?: string) {
    const where: Record<string, unknown> = {
      tenantId,
      schoolId,
      deleted: false,
    };
    if (levelId) where["classLevelId"] = levelId;
    return this.classArms.find({ where });
  }

  async createClassArm(data: Partial<ClassArm>) {
    const scope = this.requireSchoolScope(data);
    if (!data.classLevelId) {
      throw new BadRequestException("Class arm requires a class level.");
    }
    await this.assertClassLevelInScope(
      scope.tenantId,
      scope.schoolId,
      data.classLevelId,
    );
    return this.classArms.save(
      this.classArms.create({
        ...this.pickDefined(data, ["classLevelId", "arm", "displayName"]),
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        deleted: false,
        serverRevision: await this.nextServerRevision(),
      }),
    );
  }

  async updateClassArm(
    tenantId: string,
    schoolId: string,
    id: string,
    data: Partial<ClassArm>,
  ) {
    const arm = await this.classArms.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!arm) throw new NotFoundException("Class arm not found.");
    if (data.classLevelId) {
      await this.assertClassLevelInScope(tenantId, schoolId, data.classLevelId);
    }
    await this.classArms.update(
      { id, tenantId, schoolId },
      {
        ...this.pickDefined(data, ["classLevelId", "arm", "displayName"]),
        serverRevision: await this.nextServerRevision(),
      },
    );
    return this.classArms.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
  }

  async removeClassArm(tenantId: string, schoolId: string, id: string) {
    const arm = await this.classArms.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!arm) throw new NotFoundException("Class arm not found.");
    await this.classArms.update(
      { id, tenantId, schoolId },
      {
        deleted: true,
        serverRevision: await this.nextServerRevision(),
      },
    );
  }

  getSubjects(tenantId: string, schoolId: string) {
    return this.subjects.find({
      where: { tenantId, schoolId, deleted: false },
    });
  }

  async createSubject(data: Partial<Subject>) {
    const scope = this.requireSchoolScope(data);
    return this.subjects.save(
      this.subjects.create({
        ...this.pickDefined(data, ["name", "code"]),
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        deleted: false,
        serverRevision: await this.nextServerRevision(),
      }),
    );
  }

  async updateSubject(
    tenantId: string,
    schoolId: string,
    id: string,
    data: Partial<Subject>,
  ) {
    const subject = await this.subjects.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!subject) throw new NotFoundException("Subject not found.");
    await this.subjects.update(
      { id, tenantId, schoolId },
      {
        ...this.pickDefined(data, ["name", "code"]),
        serverRevision: await this.nextServerRevision(),
      },
    );
    return this.subjects.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
  }

  async removeSubject(tenantId: string, schoolId: string, id: string) {
    const subject = await this.subjects.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!subject) throw new NotFoundException("Subject not found.");
    await this.subjects.update(
      { id, tenantId, schoolId },
      {
        deleted: true,
        serverRevision: await this.nextServerRevision(),
      },
    );
  }

  getGradingSchemes(tenantId: string, schoolId: string) {
    return this.gradingSchemes.find({
      where: { tenantId, schoolId, deleted: false },
    });
  }

  async createGradingScheme(data: Partial<GradingScheme>) {
    const scope = this.requireSchoolScope(data);
    return this.gradingSchemes.save(
      this.gradingSchemes.create({
        ...this.pickDefined(data, ["name", "bands", "isDefault"]),
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        deleted: false,
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
    if (!scheme) throw new NotFoundException("Grading scheme not found.");
    await this.gradingSchemes.update(
      { id, tenantId, schoolId },
      {
        ...this.pickDefined(data, ["name", "bands", "isDefault"]),
        serverRevision: await this.nextServerRevision(),
      },
    );
    return this.gradingSchemes.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
  }

  async removeGradingScheme(tenantId: string, schoolId: string, id: string) {
    const scheme = await this.gradingSchemes.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!scheme) throw new NotFoundException("Grading scheme not found.");
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

  private requireSchoolScope(data: {
    tenantId?: string | null;
    schoolId?: string | null;
  }) {
    if (!data.tenantId || !data.schoolId) {
      throw new BadRequestException("Academic writes require school scope.");
    }

    return {
      tenantId: data.tenantId,
      schoolId: data.schoolId,
    };
  }

  private async assertAcademicYearInScope(
    tenantId: string,
    schoolId: string,
    academicYearId: string,
  ) {
    const year = await this.years.findOne({
      where: { id: academicYearId, tenantId, schoolId, deleted: false },
    });
    if (!year) {
      throw new BadRequestException(
        "Academic year does not belong to the active school scope.",
      );
    }
  }

  private async assertClassLevelInScope(
    tenantId: string,
    schoolId: string,
    classLevelId: string,
  ) {
    const level = await this.classLevels.findOne({
      where: { id: classLevelId, tenantId, schoolId, deleted: false },
    });
    if (!level) {
      throw new BadRequestException(
        "Class level does not belong to the active school scope.",
      );
    }
  }

  private pickDefined<T extends object, K extends keyof T>(
    source: Partial<T>,
    keys: K[],
  ): Partial<T> {
    return keys.reduce<Partial<T>>((result, key) => {
      if (source[key] !== undefined) {
        result[key] = source[key];
      }
      return result;
    }, {});
  }
}
