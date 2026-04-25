import { NotFoundException } from '@nestjs/common';
import { AuditService } from './audit.service';
import { AuditLog } from './audit-log.entity';
import { User } from '../users/user.entity';
import { UserRole } from '../users/user-role.enum';

describe('AuditService', () => {
  let service: AuditService;
  let repo: {
    find: jest.Mock;
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };

  const baseUser = {
    id: 'user-1',
    tenantId: 'tenant-1',
    schoolId: 'school-1',
    campusId: 'campus-1',
  } as User;

  beforeEach(() => {
    repo = {
      find: jest.fn(),
      findOne: jest.fn(),
      create: jest.fn((value) => value),
      save: jest.fn(),
    };
    service = new AuditService(repo as never);
  });

  it('lists recent audit logs school-wide for admins', async () => {
    repo.find.mockResolvedValue([
      {
        id: 'audit-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-2',
        actorUserId: 'user-2',
        eventType: 'devices.trusted_device_revoked',
        entityType: 'device',
        entityId: 'device-1',
        metadataJson: { mode: 'scoped_admin_revoke' },
        createdAt: new Date('2026-04-22T18:00:00.000Z'),
      },
    ] satisfies Partial<AuditLog>[]);

    const result = await service.listRecent({
      ...baseUser,
      role: UserRole.Admin,
    } as User);

    expect(repo.find).toHaveBeenCalledWith({
      where: {
        tenantId: 'tenant-1',
        schoolId: 'school-1',
      },
      order: { createdAt: 'DESC' },
      take: 20,
    });
    expect(result).toEqual([
      expect.objectContaining({
        id: 'audit-1',
        campusId: 'campus-2',
        eventType: 'devices.trusted_device_revoked',
        createdAt: '2026-04-22T18:00:00.000Z',
      }),
    ]);
  });

  it('limits support technicians to the active campus', async () => {
    repo.find.mockResolvedValue([]);

    await service.listRecent(
      {
        ...baseUser,
        role: UserRole.SupportTechnician,
      } as User,
      {
        eventType: 'devices.trusted_device_revoked',
        entityType: 'device',
        limit: 10,
      },
    );

    expect(repo.find).toHaveBeenCalledWith({
      where: {
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
        eventType: 'devices.trusted_device_revoked',
        entityType: 'device',
      },
      order: { createdAt: 'DESC' },
      take: 10,
    });
  });

  it('filters support technician audit responses down to operator/support events', async () => {
    repo.find.mockResolvedValue([
      {
        id: 'audit-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
        actorUserId: 'user-2',
        eventType: 'desktop.restore_package_staged',
        entityType: 'school_workspace',
        entityId: 'school-1',
        metadataJson: {},
        createdAt: new Date('2026-04-22T18:00:00.000Z'),
      },
      {
        id: 'audit-2',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
        actorUserId: 'user-3',
        eventType: 'admissions.applicant_enrolled',
        entityType: 'applicant',
        entityId: 'applicant-1',
        metadataJson: {},
        createdAt: new Date('2026-04-22T18:05:00.000Z'),
      },
    ] satisfies Partial<AuditLog>[]);

    const result = await service.listRecent({
      ...baseUser,
      role: UserRole.SupportTechnician,
    } as User);

    expect(result).toEqual([
      expect.objectContaining({
        id: 'audit-1',
        eventType: 'desktop.restore_package_staged',
      }),
    ]);
  });

  it('short-circuits forbidden support technician event queries before reading logs', async () => {
    const result = await service.listRecent(
      {
        ...baseUser,
        role: UserRole.SupportTechnician,
      } as User,
      {
        eventType: 'admissions.applicant_enrolled',
      },
    );

    expect(result).toEqual([]);
    expect(repo.find).not.toHaveBeenCalled();
  });

  it('rejects audit queries without tenant and school scope', async () => {
    await expect(
      service.listRecent({
        ...baseUser,
        tenantId: null,
        schoolId: null,
        role: UserRole.Admin,
      } as unknown as User),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('records operator audit events inside the caller scope', async () => {
    await service.recordOperatorEvent(
      {
        ...baseUser,
        role: UserRole.SupportTechnician,
      } as User,
      {
        eventType: 'restore_package_staged',
        idempotencyKey: 'operator-event-restore-package-staged-001',
        metadata: { packageFileName: 'restore.osbkx' },
      },
    );

    expect(repo.findOne).toHaveBeenCalledWith({
      where: {
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        idempotencyKey: 'operator-event-restore-package-staged-001',
      },
    });
    expect(repo.create).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
        actorUserId: 'user-1',
        eventType: 'desktop.restore_package_staged',
        entityType: 'school_workspace',
        entityId: 'school-1',
        metadataJson: { packageFileName: 'restore.osbkx' },
        idempotencyKey: 'operator-event-restore-package-staged-001',
      }),
    );
    expect(repo.save).toHaveBeenCalled();
  });

  it('replays operator audit events idempotently', async () => {
    repo.findOne.mockResolvedValue({
      id: 'audit-operator-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      idempotencyKey: 'operator-event-backup-created-001',
    } satisfies Partial<AuditLog>);

    const result = await service.recordOperatorEvent(
      {
        ...baseUser,
        role: UserRole.SupportAdmin,
      } as User,
      {
        eventType: 'backup_created',
        idempotencyKey: 'operator-event-backup-created-001',
        metadata: { fileName: 'backup.sqlite' },
      },
    );

    expect(result).toEqual({ accepted: true, replayed: true });
    expect(repo.create).not.toHaveBeenCalled();
    expect(repo.save).not.toHaveBeenCalled();
  });
});
