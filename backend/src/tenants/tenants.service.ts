import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Tenant } from './tenant.entity';

@Injectable()
export class TenantsService {
  constructor(@InjectRepository(Tenant) private readonly repo: Repository<Tenant>) {}

  findAll() {
    return this.repo.find({ where: { deleted: false } });
  }

  findById(id: string) {
    return this.repo.findOne({ where: { id, deleted: false } });
  }

  create(data: Partial<Tenant>) {
    return this.repo.save(this.repo.create(data));
  }

  async update(id: string, data: Partial<Tenant>) {
    await this.repo.update(id, data);
    return this.findById(id);
  }

  async remove(id: string) {
    const tenant = await this.repo.findOne({ where: { id } });
    if (!tenant) throw new NotFoundException('Tenant not found.');
    await this.repo.update(id, { deleted: true });
  }
}
