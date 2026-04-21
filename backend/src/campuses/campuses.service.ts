import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Campus } from './campus.entity';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class CampusesService {
  constructor(@InjectRepository(Campus) private readonly repo: Repository<Campus>) {}

  findAll(tenantId: string, schoolId?: string) {
    const where: Record<string, unknown> = { tenantId, deleted: false };
    if (schoolId) where['schoolId'] = schoolId;
    return this.repo.find({ where });
  }

  findById(tenantId: string, id: string, schoolId?: string) {
    const where: Record<string, unknown> = { id, tenantId, deleted: false };
    if (schoolId) where['schoolId'] = schoolId;
    return this.repo.findOne({ where });
  }

  async create(data: Partial<Campus>) {
    const campus = this.repo.create({
      ...data,
      registrationCode: uuidv4().split('-')[0].toUpperCase(),
    });
    return this.repo.save(campus);
  }

  async update(tenantId: string, id: string, data: Partial<Campus>, schoolId?: string) {
    const campus = await this.repo.findOne({
      where: schoolId
          ? { id, tenantId, schoolId, deleted: false }
          : { id, tenantId, deleted: false },
    });
    if (!campus) throw new NotFoundException('Campus not found.');
    await this.repo.update(id, data);
    return this.findById(tenantId, id, schoolId);
  }

  async remove(tenantId: string, id: string, schoolId?: string) {
    const campus = await this.repo.findOne({
      where: schoolId
          ? { id, tenantId, schoolId, deleted: false }
          : { id, tenantId, deleted: false },
    });
    if (!campus) throw new NotFoundException('Campus not found.');
    await this.repo.update(id, { deleted: true });
  }
}
