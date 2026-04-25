import { Injectable, NotFoundException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { DataSource, Repository } from "typeorm";
import { Campus } from "./campus.entity";
import { v4 as uuidv4 } from "uuid";

@Injectable()
export class CampusesService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(Campus) private readonly repo: Repository<Campus>,
  ) {}

  findAll(tenantId: string, schoolId: string, campusId?: string | null) {
    return this.repo.find({
      where: {
        tenantId,
        schoolId,
        ...(campusId ? { id: campusId } : {}),
        deleted: false,
      },
    });
  }

  findById(
    tenantId: string,
    id: string,
    schoolId: string,
    campusId?: string | null,
  ) {
    if (campusId && id !== campusId) {
      return null;
    }

    return this.repo.findOne({ where: { id, tenantId, schoolId, deleted: false } });
  }

  async create(tenantId: string, schoolId: string, data: Partial<Campus>) {
    const registrationCode =
      data.registrationCode?.trim() || uuidv4().split("-")[0].toUpperCase();
    const campus = this.repo.create({
      ...data,
      tenantId,
      schoolId,
      registrationCode,
      serverRevision: await this.nextServerRevision(),
    });
    return this.repo.save(campus);
  }

  async update(
    tenantId: string,
    id: string,
    data: Partial<Campus>,
    schoolId: string,
  ) {
    const campus = await this.repo.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!campus) throw new NotFoundException("Campus not found.");
    Object.assign(campus, data, {
      serverRevision: await this.nextServerRevision(),
    });
    return this.repo.save(campus);
  }

  async remove(tenantId: string, id: string, schoolId: string) {
    const campus = await this.repo.findOne({
      where: { id, tenantId, schoolId, deleted: false },
    });
    if (!campus) throw new NotFoundException("Campus not found.");
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
}
