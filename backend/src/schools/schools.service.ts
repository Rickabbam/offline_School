import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { School } from './school.entity';

@Injectable()
export class SchoolsService {
  constructor(@InjectRepository(School) private readonly repo: Repository<School>) {}

  findAll(tenantId: string) {
    return this.repo.find({ where: { tenantId, deleted: false } });
  }

  findById(id: string) {
    return this.repo.findOne({ where: { id, deleted: false } });
  }

  create(data: Partial<School>) {
    return this.repo.save(this.repo.create(data));
  }

  async update(id: string, data: Partial<School>) {
    await this.repo.update(id, data);
    return this.findById(id);
  }

  async remove(id: string) {
    const school = await this.repo.findOne({ where: { id } });
    if (!school) throw new NotFoundException('School not found.');
    await this.repo.update(id, { deleted: true });
  }
}
