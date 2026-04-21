import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';

@Injectable()
export class UsersService {
  constructor(@InjectRepository(User) private readonly repo: Repository<User>) {}

  findById(id: string) {
    return this.repo.findOne({ where: { id, deleted: false } });
  }

  findAll(tenantId: string, schoolId?: string) {
    const where: Record<string, unknown> = { tenantId, deleted: false };
    if (schoolId) where['schoolId'] = schoolId;
    return this.repo.find({ where });
  }

  async remove(id: string) {
    const user = await this.repo.findOne({ where: { id } });
    if (!user) throw new NotFoundException('User not found.');
    await this.repo.update(id, { deleted: true });
  }
}
