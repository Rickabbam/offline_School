import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';
import { Campus } from '../campuses/campus.entity';
import { Staff } from './staff.entity';
import { StaffService } from './staff.service';

type MockRepo<T extends object> = Partial<
  Record<keyof Repository<T>, jest.Mock>
>;

describe('StaffService', () => {
  let dataSource: { query: jest.Mock };
  let staff: MockRepo<Staff>;
  let campuses: MockRepo<Campus>;
  let service: StaffService;

  beforeEach(() => {
    dataSource = {
      query: jest.fn().mockResolvedValue([{ revision: '51' }]),
    };
    staff = {
      create: jest.fn((value) => value),
      find: jest.fn(),
      findOne: jest.fn(),
      save: jest.fn((value) => Promise.resolve(value)),
      update: jest.fn(),
    };
    campuses = {
      findOne: jest.fn().mockResolvedValue({
        id: 'campus-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        deleted: false,
      } as Campus),
    };

    service = new StaffService(
      dataSource as unknown as DataSource,
      staff as unknown as Repository<Staff>,
      campuses as unknown as Repository<Campus>,
    );
  });

  it('rejects staff creation when a campus-scoped user targets another campus', async () => {
    await expect(
      service.create('tenant-1', 'school-1', 'campus-1', {
        firstName: 'Ama',
        lastName: 'Mensah',
        campusId: 'campus-2',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);

    expect(staff.save).not.toHaveBeenCalled();
    expect(dataSource.query).not.toHaveBeenCalled();
  });

  it('creates staff only when the campus is in scope', async () => {
    await service.create('tenant-1', 'school-1', 'campus-1', {
      firstName: 'Ama',
      lastName: 'Mensah',
      campusId: 'campus-1',
    });

    expect(campuses.findOne).toHaveBeenCalledWith({
      where: {
        id: 'campus-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        deleted: false,
      },
    });
    expect(staff.save).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
        serverRevision: 51,
      }),
    );
  });

  it('filters staff searches to the current campus for campus-scoped users', async () => {
    staff.find!.mockResolvedValue([]);

    await service.findAll('tenant-1', 'school-1', 'campus-1', 'Ama');

    expect(staff.find).toHaveBeenCalledWith({
      where: [
        expect.objectContaining({
          tenantId: 'tenant-1',
          schoolId: 'school-1',
          campusId: 'campus-1',
          deleted: false,
          firstName: expect.anything(),
        }),
        expect.objectContaining({
          tenantId: 'tenant-1',
          schoolId: 'school-1',
          campusId: 'campus-1',
          deleted: false,
          lastName: expect.anything(),
        }),
      ],
    });
  });

  it('rejects staff update when the new campus is outside scope', async () => {
    staff.findOne!.mockResolvedValue({
      id: 'staff-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
      deleted: false,
    } as Staff);

    await expect(
      service.update('tenant-1', 'school-1', 'campus-1', 'staff-1', {
        campusId: 'campus-2',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);

    expect(staff.update).not.toHaveBeenCalled();
    expect(dataSource.query).not.toHaveBeenCalled();
  });

  it('rejects staff updates outside the current campus scope', async () => {
    staff.findOne!.mockResolvedValue(null);

    await expect(
      service.update('tenant-1', 'school-1', 'campus-1', 'staff-2', {
        firstName: 'Kojo',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(staff.update).not.toHaveBeenCalled();
  });
});
