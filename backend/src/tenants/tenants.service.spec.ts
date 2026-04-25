import { NotFoundException } from '@nestjs/common';
import { TenantsService } from './tenants.service';
import { TenantStatus } from './tenant.entity';

describe('TenantsService', () => {
  const repo = {
    find: jest.fn(),
    findOne: jest.fn(),
    save: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  };

  let service: TenantsService;

  beforeEach(() => {
    jest.resetAllMocks();
    service = new TenantsService(repo as never);
  });

  it('returns the current scoped tenant as a stable summary', async () => {
    repo.findOne.mockResolvedValue({
      id: 'tenant-1',
      name: 'Pilot Tenant',
      status: TenantStatus.Trial,
      contactEmail: 'pilot@example.com',
      contactPhone: '0200000000',
      deleted: false,
      createdAt: new Date('2026-04-24T10:00:00.000Z'),
      updatedAt: new Date('2026-04-24T11:00:00.000Z'),
    });

    await expect(service.findScopedTenant('tenant-1')).resolves.toEqual({
      id: 'tenant-1',
      name: 'Pilot Tenant',
      status: TenantStatus.Trial,
      contactEmail: 'pilot@example.com',
      contactPhone: '0200000000',
      deleted: false,
      createdAt: '2026-04-24T10:00:00.000Z',
      updatedAt: '2026-04-24T11:00:00.000Z',
    });
    expect(repo.findOne).toHaveBeenCalledWith({
      where: {
        id: 'tenant-1',
        deleted: false,
      },
    });
  });

  it('rejects current-tenant lookups outside the active tenant scope', async () => {
    repo.findOne.mockResolvedValue(null);

    await expect(service.findScopedTenant('tenant-missing')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
