import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Tenant } from './tenant.entity';

@Injectable()
export class TenantsService {
  constructor(@InjectRepository(Tenant) private readonly repo: Repository<Tenant>) {}

  async findAll() {
    const tenants = await this.repo.find({ where: { deleted: false } });
    return tenants.map((tenant) => this.toTenantSummary(tenant));
  }

  async findById(id: string) {
    const tenant = await this.repo.findOne({ where: { id, deleted: false } });
    return tenant ? this.toTenantSummary(tenant) : null;
  }

  async findScopedTenant(id: string) {
    const tenant = await this.repo.findOne({ where: { id, deleted: false } });
    if (!tenant) {
      throw new NotFoundException('Tenant not found.');
    }
    return this.toTenantSummary(tenant);
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

  private toTenantSummary(tenant: Tenant) {
    return {
      id: tenant.id,
      name: tenant.name,
      status: tenant.status,
      contactEmail: tenant.contactEmail,
      contactPhone: tenant.contactPhone,
      deleted: tenant.deleted,
      createdAt: tenant.createdAt.toISOString(),
      updatedAt: tenant.updatedAt.toISOString(),
    };
  }
}
