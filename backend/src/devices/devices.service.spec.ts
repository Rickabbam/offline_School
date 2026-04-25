import { NotFoundException } from '@nestjs/common';
import { Repository } from 'typeorm';
import { AuditService } from '../audit/audit.service';
import { DevicesService } from './devices.service';
import { Device } from './device.entity';
import { User } from '../users/user.entity';
import { UserRole } from '../users/user-role.enum';

type MockRepo<T extends object> = Partial<Record<keyof Repository<T>, jest.Mock>>;

describe('DevicesService', () => {
  let devices: MockRepo<Device>;
  let audit: { record: jest.Mock };
  let service: DevicesService;

  const campusAdmin = {
    id: 'user-1',
    email: 'admin@example.com',
    passwordHash: 'hash',
    fullName: 'Campus Admin',
    role: UserRole.Admin,
    tenantId: 'tenant-1',
    schoolId: 'school-1',
    campusId: 'campus-1',
    isActive: true,
    deleted: false,
    createdAt: new Date(),
    updatedAt: new Date(),
  } as User;

  const supportAdmin = {
    ...campusAdmin,
    id: 'user-2',
    role: UserRole.SupportAdmin,
    campusId: null,
  } as User;

  beforeEach(() => {
    devices = {
      find: jest.fn(),
      findOne: jest.fn(),
      update: jest.fn(),
    };
    audit = { record: jest.fn() };
    service = new DevicesService(
      devices as unknown as Repository<Device>,
      audit as unknown as AuditService,
    );
  });

  it('lists trusted devices scoped to the current campus for non-support admins', async () => {
    devices.find!.mockResolvedValue([]);

    await service.listTrustedDevices(campusAdmin);

    expect(devices.find).toHaveBeenCalledWith({
      where: {
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
        isActive: true,
      },
      order: { updatedAt: 'DESC', createdAt: 'DESC' },
    });
  });

  it('lists trusted devices school-wide for support admins', async () => {
    devices.find!.mockResolvedValue([]);

    await service.listTrustedDevices(supportAdmin);

    expect(devices.find).toHaveBeenCalledWith({
      where: {
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        isActive: true,
      },
      order: { updatedAt: 'DESC', createdAt: 'DESC' },
    });
  });

  it('revokes the current trusted device inside the user scope', async () => {
    devices.findOne!.mockResolvedValue({
      id: 'device-1',
      deviceName: 'Front Desk PC',
      deviceFingerprint: 'fp-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
      registeredByUserId: 'user-1',
      isActive: true,
      lastUsedAt: null,
      createdAt: new Date('2026-04-22T08:00:00.000Z'),
      updatedAt: new Date('2026-04-22T09:00:00.000Z'),
    } as Device);

    const result = await service.revokeCurrentTrustedDevice(campusAdmin, 'fp-1');

    expect(devices.findOne).toHaveBeenCalledWith({
      where: {
        deviceFingerprint: 'fp-1',
        registeredByUserId: 'user-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
        isActive: true,
      },
    });
    expect(devices.update).toHaveBeenCalledWith('device-1', { isActive: false });
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        eventType: 'devices.current_trusted_device_revoked',
        entityType: 'device',
        entityId: 'device-1',
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        id: 'device-1',
        isActive: false,
      }),
    );
  });

  it('allows a cashier to revoke only their own current trusted device', async () => {
    const cashier = {
      ...campusAdmin,
      id: 'cashier-1',
      role: UserRole.Cashier,
    } as User;
    devices.findOne!.mockResolvedValue({
      id: 'device-cashier-1',
      deviceName: 'Cashier Desk PC',
      deviceFingerprint: 'fp-cashier-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
      registeredByUserId: 'cashier-1',
      isActive: true,
      lastUsedAt: null,
      createdAt: new Date('2026-04-22T08:00:00.000Z'),
      updatedAt: new Date('2026-04-22T09:00:00.000Z'),
    } as Device);

    const result = await service.revokeCurrentTrustedDevice(
      cashier,
      'fp-cashier-1',
    );

    expect(devices.findOne).toHaveBeenCalledWith({
      where: {
        deviceFingerprint: 'fp-cashier-1',
        registeredByUserId: 'cashier-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
        isActive: true,
      },
    });
    expect(devices.update).toHaveBeenCalledWith('device-cashier-1', {
      isActive: false,
    });
    expect(result).toEqual(
      expect.objectContaining({
        id: 'device-cashier-1',
        isActive: false,
      }),
    );
  });

  it('blocks current-device revocation when the fingerprint belongs to another user in scope', async () => {
    devices.findOne!.mockResolvedValue(null);

    await expect(
      service.revokeCurrentTrustedDevice(campusAdmin, 'fp-owned-by-cashier'),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(devices.findOne).toHaveBeenCalledWith({
      where: {
        deviceFingerprint: 'fp-owned-by-cashier',
        registeredByUserId: 'user-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
        isActive: true,
      },
    });
    expect(devices.update).not.toHaveBeenCalled();
    expect(audit.record).not.toHaveBeenCalled();
  });

  it('allows a support admin to revoke a trusted device across campus scope', async () => {
    devices.findOne!.mockResolvedValue({
      id: 'device-2',
      deviceName: 'Library PC',
      deviceFingerprint: 'fp-2',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-2',
      registeredByUserId: 'user-3',
      isActive: true,
      lastUsedAt: null,
      createdAt: new Date('2026-04-22T08:00:00.000Z'),
      updatedAt: new Date('2026-04-22T09:00:00.000Z'),
    } as Device);

    const result = await service.revokeTrustedDevice(supportAdmin, 'device-2');

    expect(devices.findOne).toHaveBeenCalledWith({
      where: {
        id: 'device-2',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        isActive: true,
      },
    });
    expect(devices.update).toHaveBeenCalledWith('device-2', { isActive: false });
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        eventType: 'devices.trusted_device_revoked',
        entityType: 'device',
        entityId: 'device-2',
        campusId: 'campus-2',
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        id: 'device-2',
        isActive: false,
      }),
    );
  });

  it('rejects revocation for devices outside the active scope', async () => {
    devices.findOne!.mockResolvedValue(null);

    await expect(
      service.revokeTrustedDevice(campusAdmin, 'missing-device'),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(devices.update).not.toHaveBeenCalled();
  });
});
