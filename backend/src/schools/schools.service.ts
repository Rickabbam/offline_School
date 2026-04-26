import { Injectable, NotFoundException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { DataSource, Repository } from "typeorm";
import { School } from "./school.entity";

@Injectable()
export class SchoolsService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(School) private readonly repo: Repository<School>,
  ) {}

  findAll(tenantId: string, schoolId?: string | null) {
    return this.repo.find({
      where: {
        tenantId,
        ...(schoolId ? { id: schoolId } : {}),
        deleted: false,
      },
    });
  }

  findById(tenantId: string, id: string, schoolId?: string | null) {
    if (schoolId && id !== schoolId) {
      return null;
    }

    return this.repo.findOne({
      where: {
        id,
        tenantId,
        deleted: false,
      },
    });
  }

  async create(tenantId: string, data: Partial<School>) {
    return this.repo.save(
      this.repo.create({
        ...this.schoolMutableFields(data),
        tenantId,
        serverRevision: await this.nextServerRevision(),
      }),
    );
  }

  async update(
    tenantId: string,
    id: string,
    data: Partial<School>,
    schoolId?: string | null,
  ) {
    if (schoolId && id !== schoolId) {
      throw new NotFoundException("School not found.");
    }

    const school = await this.repo.findOne({
      where: {
        id,
        tenantId,
        deleted: false,
      },
    });
    if (!school) throw new NotFoundException("School not found.");
    Object.assign(school, this.schoolMutableFields(data), {
      serverRevision: await this.nextServerRevision(),
    });
    return this.repo.save(school);
  }

  async remove(tenantId: string, id: string) {
    const school = await this.repo.findOne({
      where: { id, tenantId, deleted: false },
    });
    if (!school) throw new NotFoundException("School not found.");
    await this.repo.update(id, {
      deleted: true,
      serverRevision: await this.nextServerRevision(),
    });
  }
  private async nextServerRevision() {
    const result = (await this.dataSource.query(
      "SELECT nextval('sync_server_revision_seq')::bigint AS revision",
    )) as { revision: string | number }[];
    return Number(result[0].revision);
  }

  private schoolMutableFields(data: Partial<School>): Partial<School> {
    return {
      ...(data.name !== undefined ? { name: data.name } : {}),
      ...(data.shortName !== undefined ? { shortName: data.shortName } : {}),
      ...(data.schoolType !== undefined ? { schoolType: data.schoolType } : {}),
      ...(data.address !== undefined ? { address: data.address } : {}),
      ...(data.region !== undefined ? { region: data.region } : {}),
      ...(data.district !== undefined ? { district: data.district } : {}),
      ...(data.contactPhone !== undefined
        ? { contactPhone: data.contactPhone }
        : {}),
      ...(data.contactEmail !== undefined
        ? { contactEmail: data.contactEmail }
        : {}),
      ...(data.onboardingDefaults !== undefined
        ? { onboardingDefaults: data.onboardingDefaults }
        : {}),
    };
  }
}
