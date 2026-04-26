import { NotFoundException } from '@nestjs/common';
import { SchoolsService } from './schools.service';

describe('SchoolsService', () => {
  const dataSource = {
    query: jest.fn(),
  };
  const repo = {
    find: jest.fn(),
    findOne: jest.fn(),
    create: jest.fn(),
    save: jest.fn(),
    update: jest.fn(),
  };

  let service: SchoolsService;

  beforeEach(() => {
    jest.resetAllMocks();
    dataSource.query.mockResolvedValue([{ revision: 1 }]);
    service = new SchoolsService(dataSource as never, repo as never);
  });

  it('scopes school lists to the assigned school for school admins', async () => {
    repo.find.mockResolvedValue([]);

    await service.findAll('tenant-1', 'school-1');

    expect(repo.find).toHaveBeenCalledWith({
      where: {
        tenantId: 'tenant-1',
        id: 'school-1',
        deleted: false,
      },
    });
  });

  it('allows support admins to list all schools in the active tenant', async () => {
    repo.find.mockResolvedValue([]);

    await service.findAll('tenant-1', null);

    expect(repo.find).toHaveBeenCalledWith({
      where: {
        tenantId: 'tenant-1',
        deleted: false,
      },
    });
  });

  it('blocks school admin reads outside their assigned school', async () => {
    expect(service.findById('tenant-1', 'school-2', 'school-1')).toBeNull();
    expect(repo.findOne).not.toHaveBeenCalled();
  });

  it('blocks school admin updates outside their assigned school', async () => {
    await expect(
      service.update('tenant-1', 'school-2', { name: 'Other' }, 'school-1'),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(repo.findOne).not.toHaveBeenCalled();
    expect(repo.save).not.toHaveBeenCalled();
  });

  it('does not allow create payloads to override tenant scope', async () => {
    repo.create.mockImplementation((value) => value);
    repo.save.mockImplementation(async (value) => value);

    const result = await service.create('tenant-1', {
      id: 'school-x',
      tenantId: 'tenant-x',
      name: 'Scoped School',
    });

    expect(repo.create).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: 'tenant-1',
        name: 'Scoped School',
      }),
    );
    expect(repo.create).toHaveBeenCalledWith(
      expect.not.objectContaining({
        id: 'school-x',
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        tenantId: 'tenant-1',
      }),
    );
  });

  it('does not allow update payloads to mutate school identity or tenant scope', async () => {
    const existing = {
      id: 'school-1',
      tenantId: 'tenant-1',
      name: 'Original',
      deleted: false,
    };
    repo.findOne.mockResolvedValue(existing);
    repo.save.mockImplementation(async (value) => value);

    const result = await service.update(
      'tenant-1',
      'school-1',
      {
        id: 'school-x',
        tenantId: 'tenant-x',
        name: 'Renamed',
      },
      'school-1',
    );

    expect(result).toEqual(
      expect.objectContaining({
        id: 'school-1',
        tenantId: 'tenant-1',
        name: 'Renamed',
        serverRevision: 1,
      }),
    );
  });
});
