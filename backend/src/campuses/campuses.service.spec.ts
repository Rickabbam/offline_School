import { NotFoundException } from '@nestjs/common';
import { CampusesService } from './campuses.service';

describe('CampusesService', () => {
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

  let service: CampusesService;

  beforeEach(() => {
    jest.resetAllMocks();
    dataSource.query.mockResolvedValue([{ revision: 1 }]);
    service = new CampusesService(dataSource as never, repo as never);
  });

  it('scopes list queries to both tenant and school', async () => {
    repo.find.mockResolvedValue([]);

    await service.findAll('tenant-1', 'school-1');

    expect(repo.find).toHaveBeenCalledWith({
      where: {
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        deleted: false,
      },
    });
  });

  it('scopes support technician campus lists to the active campus', async () => {
    repo.find.mockResolvedValue([]);

    await service.findAll('tenant-1', 'school-1', 'campus-1');

    expect(repo.find).toHaveBeenCalledWith({
      where: {
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        id: 'campus-1',
        deleted: false,
      },
    });
  });

  it('blocks support technician reads outside the active campus before querying', async () => {
    expect(
      service.findById('tenant-1', 'campus-2', 'school-1', 'campus-1'),
    ).toBeNull();
    expect(repo.findOne).not.toHaveBeenCalled();
  });

  it('forces tenant and school scope on create', async () => {
    repo.create.mockImplementation((value) => value);
    repo.save.mockImplementation(async (value) => value);

    const result = await service.create('tenant-1', 'school-1', {
      tenantId: 'tenant-x',
      schoolId: 'school-x',
      name: 'Main Campus',
    });

    expect(repo.create).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        name: 'Main Campus',
        registrationCode: expect.any(String),
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        tenantId: 'tenant-1',
        schoolId: 'school-1',
      }),
    );
  });

  it('preserves an explicit campus registration code from the setup flow', async () => {
    repo.create.mockImplementation((value) => value);
    repo.save.mockImplementation(async (value) => value);

    const result = await service.create('tenant-1', 'school-1', {
      name: 'Main Campus',
      registrationCode: 'MAIN',
    });

    expect(repo.create).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        registrationCode: 'MAIN',
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        registrationCode: 'MAIN',
      }),
    );
  });

  it('rejects updates outside the authenticated school scope', async () => {
    repo.findOne.mockResolvedValue(null);

    await expect(
      service.update('tenant-1', 'campus-1', { name: 'Renamed' }, 'school-1'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('does not allow update payloads to mutate campus identity or scope', async () => {
    const existing = {
      id: 'campus-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      name: 'Original',
      deleted: false,
    };
    repo.findOne.mockResolvedValue(existing);
    repo.save.mockImplementation(async (value) => value);

    const result = await service.update(
      'tenant-1',
      'campus-1',
      {
        id: 'campus-x',
        tenantId: 'tenant-x',
        schoolId: 'school-x',
        name: 'Renamed',
      },
      'school-1',
    );

    expect(result).toEqual(
      expect.objectContaining({
        id: 'campus-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        name: 'Renamed',
        serverRevision: 1,
      }),
    );
  });
});
