import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike } from 'typeorm';
import { Staff } from './staff.entity';

@Injectable()
export class StaffService {
  constructor(@InjectRepository(Staff) private readonly repo: Repository<Staff>) {}

  findAll(tenantId: string, schoolId: string, search?: string) {
    if (search) {
      return this.repo.find({
        where: [
          { tenantId, schoolId, deleted: false, firstName: ILike(`%${search}%`) },
          { tenantId, schoolId, deleted: false, lastName: ILike(`%${search}%`) },
        ],
      });
    }
    return this.repo.find({ where: { tenantId, schoolId, deleted: false } });
  }

  findById(id: string) {
    return this.repo.findOne({ where: { id, deleted: false } });
  }

  create(tenantId: string, schoolId: string, data: Partial<Staff>) {
    return this.repo.save(this.repo.create({ ...data, tenantId, schoolId, syncStatus: 'local' }));
  }

  async update(id: string, data: Partial<Staff>) {
    const staff = await this.repo.findOne({ where: { id } });
    if (!staff) throw new NotFoundException('Staff member not found.');
    await this.repo.update(id, { ...data, syncStatus: 'local' });
    return this.findById(id);
  }

  async remove(id: string) {
    const staff = await this.repo.findOne({ where: { id } });
    if (!staff) throw new NotFoundException('Staff member not found.');
    await this.repo.update(id, { deleted: true });
  }
}
