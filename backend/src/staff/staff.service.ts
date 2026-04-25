import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository, ILike } from 'typeorm';
import { Campus } from '../campuses/campus.entity';
import { Staff } from './staff.entity';

@Injectable()
export class StaffService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(Staff) private readonly repo: Repository<Staff>,
    @InjectRepository(Campus) private readonly campuses: Repository<Campus>,
  ) {}

  findAll(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    search?: string,
  ) {
    const scope = this.staffScopeWhere(tenantId, schoolId, campusId);
    if (search) {
      return this.repo.find({
        where: [
          { ...scope, firstName: ILike(`%${search}%`) },
          { ...scope, lastName: ILike(`%${search}%`) },
        ],
      });
    }
    return this.repo.find({ where: scope });
  }

  findById(
    tenantId: string,
    schoolId: string,
    campusId: string | null,
    id: string,
  ) {
    return this.repo.findOne({
      where: {
        id,
        ...this.staffScopeWhere(tenantId, schoolId, campusId),
      },
    });
  }

  async create(
    tenantId: string,
    schoolId: string,
    userCampusId: string | null,
    data: Partial<Staff>,
  ) {
    const campusId = await this.resolveRequestedCampusId(
      tenantId,
      schoolId,
      userCampusId,
      data.campusId,
    );
    return this.repo.save(
      this.repo.create({
        ...data,
        tenantId,
        schoolId,
        campusId,
        serverRevision: await this.nextServerRevision(),
        syncStatus: 'local',
      }),
    );
  }

  async update(
    tenantId: string,
    schoolId: string,
    userCampusId: string | null,
    id: string,
    data: Partial<Staff>,
  ) {
    const staff = await this.repo.findOne({
      where: {
        id,
        ...this.staffScopeWhere(tenantId, schoolId, userCampusId),
      },
    });
    if (!staff) throw new NotFoundException('Staff member not found.');
    const campusId =
      data.campusId === undefined
        ? staff.campusId
        : await this.resolveRequestedCampusId(
            tenantId,
            schoolId,
            userCampusId,
            data.campusId,
          );
    await this.repo.update({ id, tenantId, schoolId }, {
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
    const staff = await this.repo.findOne({
      where: {
        id,
        ...this.staffScopeWhere(tenantId, schoolId, campusId),
      },
    });
    if (!staff) throw new NotFoundException('Staff member not found.');
    await this.repo.update({ id, tenantId, schoolId }, {
      deleted: true,
      serverRevision: await this.nextServerRevision(),
      syncStatus: 'local',
    });
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

  private staffScopeWhere(
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

  private async resolveRequestedCampusId(
    tenantId: string,
    schoolId: string,
    userCampusId: string | null,
    requestedCampusId: string | null | undefined,
  ) {
    if (userCampusId) {
      if (requestedCampusId && requestedCampusId != userCampusId) {
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
