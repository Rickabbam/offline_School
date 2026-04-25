import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { AuthService } from './auth.service';
import { AuditService } from '../audit/audit.service';
import { User } from '../users/user.entity';
import { Device } from '../devices/device.entity';
import { UserRole } from '../users/user-role.enum';
import { JwtPayload } from './jwt.strategy';

jest.mock('bcrypt', () => ({
  compare: jest.fn(),
  hash: jest.fn(),
}));

describe('AuthService', () => {
  let service: AuthService;

  const usersRepo = {
    findOne: jest.fn(),
    update: jest.fn(),
  };

  const devicesRepo = {
    findOne: jest.fn(),
    create: jest.fn(),
    save: jest.fn(),
    update: jest.fn(),
  };

  const jwtService = {
    sign: jest.fn(),
    verify: jest.fn(),
  };

  const auditService = {
    record: jest.fn(),
  };

  const activeUser: User = {
    id: 'user-1',
    email: 'admin@example.com',
    passwordHash: 'hashed-password',
    fullName: 'Admin User',
    role: UserRole.Admin,
    tenantId: 'tenant-1',
    schoolId: 'school-1',
    campusId: 'campus-1',
    isActive: true,
    sessionVersion: 1,
    deleted: false,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  beforeEach(async () => {
    jest.resetAllMocks();

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: getRepositoryToken(User), useValue: usersRepo },
        { provide: getRepositoryToken(Device), useValue: devicesRepo },
        { provide: JwtService, useValue: jwtService },
        { provide: AuditService, useValue: auditService },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  it('issues distinct access and refresh tokens on login', async () => {
    usersRepo.findOne.mockResolvedValue(activeUser);
    devicesRepo.findOne.mockResolvedValue(null);
    (bcrypt.compare as jest.Mock).mockResolvedValue(true);
    jwtService.sign
      .mockReturnValueOnce('access-token')
      .mockReturnValueOnce('refresh-token');

    const result = await service.login({
      email: 'admin@example.com',
      password: 'secret123',
    });

    expect(result.accessToken).toBe('access-token');
    expect(result.refreshToken).toBe('refresh-token');
    expect(devicesRepo.findOne).not.toHaveBeenCalled();
    expect(jwtService.sign).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining<Partial<JwtPayload>>({
        sub: activeUser.id,
        tokenType: 'access',
        sessionVersion: activeUser.sessionVersion,
      }),
      { expiresIn: '15m' },
    );
    expect(jwtService.sign).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining<Partial<JwtPayload>>({
        sub: activeUser.id,
        tokenType: 'refresh',
        sessionVersion: activeUser.sessionVersion,
        deviceFingerprint: null,
      }),
      { expiresIn: '30d' },
    );
  });

  it('allows first-time login from an untrusted device without binding refresh tokens', async () => {
    usersRepo.findOne.mockResolvedValue(activeUser);
    devicesRepo.findOne.mockResolvedValue(null);
    (bcrypt.compare as jest.Mock).mockResolvedValue(true);
    jwtService.sign
      .mockReturnValueOnce('access-token')
      .mockReturnValueOnce('refresh-token');

    const result = await service.login({
      email: 'admin@example.com',
      password: 'secret123',
      deviceFingerprint: 'new-device-fingerprint',
    });

    expect(result.accessToken).toBe('access-token');
    expect(result.refreshToken).toBe('refresh-token');
    expect(devicesRepo.findOne).toHaveBeenCalledWith({
      where: {
        deviceFingerprint: 'new-device-fingerprint',
      },
    });
    expect(jwtService.sign).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining<Partial<JwtPayload>>({
        tokenType: 'refresh',
        sessionVersion: activeUser.sessionVersion,
        deviceFingerprint: null,
      }),
      { expiresIn: '30d' },
    );
  });

  it('rejects using an access token at the refresh endpoint', async () => {
    jwtService.verify.mockReturnValue({
      sub: activeUser.id,
      email: activeUser.email,
      role: activeUser.role,
      tenantId: activeUser.tenantId,
      schoolId: activeUser.schoolId,
      campusId: activeUser.campusId,
      sessionVersion: activeUser.sessionVersion,
      tokenType: 'access',
    } satisfies JwtPayload);

    await expect(service.refreshToken('access-token')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(usersRepo.findOne).not.toHaveBeenCalled();
  });

  it('binds token refresh to the same trusted device fingerprint', async () => {
    jwtService.verify.mockReturnValue({
      sub: activeUser.id,
      email: activeUser.email,
      role: activeUser.role,
      tenantId: activeUser.tenantId,
      schoolId: activeUser.schoolId,
      campusId: activeUser.campusId,
      sessionVersion: activeUser.sessionVersion,
      deviceFingerprint: 'device-fingerprint',
      tokenType: 'refresh',
    } satisfies JwtPayload);
    usersRepo.findOne.mockResolvedValue(activeUser);
    devicesRepo.findOne.mockResolvedValue({
      id: 'device-1',
      deviceFingerprint: 'device-fingerprint',
      tenantId: activeUser.tenantId,
      schoolId: activeUser.schoolId,
      campusId: activeUser.campusId,
      registeredByUserId: activeUser.id,
      isActive: true,
    });
    jwtService.sign
      .mockReturnValueOnce('access-token')
      .mockReturnValueOnce('refresh-token');

    const result = await service.refreshToken(
      'refresh-token-old',
      'device-fingerprint',
    );

    expect(result.accessToken).toBe('access-token');
    expect(result.refreshToken).toBe('refresh-token');
    expect(devicesRepo.findOne).toHaveBeenCalledWith({
      where: {
        deviceFingerprint: 'device-fingerprint',
        registeredByUserId: activeUser.id,
        isActive: true,
      },
    });
    expect(jwtService.sign).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining<Partial<JwtPayload>>({
        tokenType: 'refresh',
        sessionVersion: activeUser.sessionVersion,
        deviceFingerprint: 'device-fingerprint',
      }),
      { expiresIn: '30d' },
    );
  });

  it('rejects device-bound refresh when the request fingerprint does not match', async () => {
    jwtService.verify.mockReturnValue({
      sub: activeUser.id,
      email: activeUser.email,
      role: activeUser.role,
      tenantId: activeUser.tenantId,
      schoolId: activeUser.schoolId,
      campusId: activeUser.campusId,
      sessionVersion: activeUser.sessionVersion,
      deviceFingerprint: 'device-fingerprint',
      tokenType: 'refresh',
    } satisfies JwtPayload);
    usersRepo.findOne.mockResolvedValue(activeUser);

    await expect(
      service.refreshToken('refresh-token-old', 'different-device'),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(devicesRepo.findOne).not.toHaveBeenCalled();
  });

  it('registers a trusted device and returns a raw offline token', async () => {
    usersRepo.findOne.mockResolvedValue(activeUser);
    devicesRepo.findOne.mockResolvedValue(null);
    (bcrypt.hash as jest.Mock).mockResolvedValue('hashed-offline-token');
    devicesRepo.create.mockImplementation((value: Partial<Device>) => ({
      ...value,
      id: 'device-1',
    }));
    devicesRepo.save.mockResolvedValue(undefined);

    const result = await service.registerDevice(activeUser.id, {
      deviceName: 'Admin Office PC',
      deviceFingerprint: 'device-fingerprint',
    });

    expect(result.deviceId).toBe('device-1');
    expect(result.offlineToken).toContain('-');
    expect(devicesRepo.findOne).toHaveBeenCalledWith({
      where: { deviceFingerprint: 'device-fingerprint' },
    });
    expect(devicesRepo.create).toHaveBeenCalledWith(
      expect.objectContaining({
        deviceName: 'Admin Office PC',
        deviceFingerprint: 'device-fingerprint',
        offlineTokenHash: 'hashed-offline-token',
        schoolId: activeUser.schoolId,
        registeredByUserId: activeUser.id,
      }),
    );
    expect(auditService.record).toHaveBeenCalledWith({
      tenantId: activeUser.tenantId,
      schoolId: activeUser.schoolId,
      campusId: activeUser.campusId,
      actorUserId: activeUser.id,
      eventType: 'devices.trusted_device_registered',
      entityType: 'device',
      entityId: 'device-1',
      metadata: {
        deviceName: 'Admin Office PC',
        deviceFingerprint: 'device-fingerprint',
        mode: 'new_registration',
      },
    });
  });

  it('rejects trusted device registration before the user has tenant and school scope', async () => {
    usersRepo.findOne.mockResolvedValue({
      ...activeUser,
      tenantId: null,
      schoolId: null,
      campusId: null,
    } satisfies User);

    await expect(
      service.registerDevice(activeUser.id, {
        deviceName: 'Admin Office PC',
        deviceFingerprint: 'device-fingerprint',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(devicesRepo.findOne).not.toHaveBeenCalled();
  });

  it('rotates the trusted device token when the same user re-registers the same fingerprint', async () => {
    usersRepo.findOne.mockResolvedValue(activeUser);
    devicesRepo.findOne.mockResolvedValue({
      id: 'device-1',
      deviceName: 'Old Name',
      deviceFingerprint: 'device-fingerprint',
      offlineTokenHash: 'old-hash',
      tenantId: null,
      schoolId: null,
      campusId: null,
      registeredByUserId: activeUser.id,
      isActive: false,
    });
    devicesRepo.save.mockResolvedValue(undefined);
    (bcrypt.hash as jest.Mock).mockResolvedValue('hashed-offline-token');

    const result = await service.registerDevice(activeUser.id, {
      deviceName: 'Admin Office PC',
      deviceFingerprint: 'device-fingerprint',
    });

    expect(result.deviceId).toBe('device-1');
    expect(devicesRepo.create).not.toHaveBeenCalled();
    expect(devicesRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: 'device-1',
        deviceName: 'Admin Office PC',
        offlineTokenHash: 'hashed-offline-token',
        tenantId: activeUser.tenantId,
        schoolId: activeUser.schoolId,
        campusId: activeUser.campusId,
        registeredByUserId: activeUser.id,
        isActive: true,
      }),
    );
    expect(auditService.record).toHaveBeenCalledWith({
      tenantId: activeUser.tenantId,
      schoolId: activeUser.schoolId,
      campusId: activeUser.campusId,
      actorUserId: activeUser.id,
      eventType: 'devices.trusted_device_registered',
      entityType: 'device',
      entityId: 'device-1',
      metadata: {
        deviceName: 'Admin Office PC',
        deviceFingerprint: 'device-fingerprint',
        mode: 'credential_rotation',
      },
    });
  });

  it('reassigns a revoked device fingerprint to a different user and audits the reassignment', async () => {
    const secondUser: User = {
      ...activeUser,
      id: 'user-2',
      email: 'operator@example.com',
    };
    usersRepo.findOne.mockResolvedValue(secondUser);
    devicesRepo.findOne.mockResolvedValue({
      id: 'device-foreign',
      deviceName: 'Old Device',
      deviceFingerprint: 'device-fingerprint',
      offlineTokenHash: 'old-hash',
      tenantId: secondUser.tenantId,
      schoolId: secondUser.schoolId,
      campusId: secondUser.campusId,
      registeredByUserId: activeUser.id,
      isActive: false,
    });
    devicesRepo.save.mockResolvedValue(undefined);
    (bcrypt.hash as jest.Mock).mockResolvedValue('hashed-offline-token');

    const result = await service.registerDevice(secondUser.id, {
      deviceName: 'Reassigned Device',
      deviceFingerprint: 'device-fingerprint',
    });

    expect(result.deviceId).toBe('device-foreign');
    expect(devicesRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: 'device-foreign',
        deviceName: 'Reassigned Device',
        registeredByUserId: secondUser.id,
        isActive: true,
      }),
    );
    expect(auditService.record).toHaveBeenCalledWith({
      tenantId: secondUser.tenantId,
      schoolId: secondUser.schoolId,
      campusId: secondUser.campusId,
      actorUserId: secondUser.id,
      eventType: 'devices.trusted_device_registered',
      entityType: 'device',
      entityId: 'device-foreign',
      metadata: {
        deviceName: 'Reassigned Device',
        deviceFingerprint: 'device-fingerprint',
        mode: 'reassigned_after_revoke',
      },
    });
  });

  it('rejects duplicate active device fingerprints owned by another user', async () => {
    usersRepo.findOne.mockResolvedValue(activeUser);
    devicesRepo.findOne.mockResolvedValue({
      id: 'existing-device',
      registeredByUserId: 'user-2',
      isActive: true,
    });

    await expect(
      service.registerDevice(activeUser.id, {
        deviceName: 'Admin Office PC',
        deviceFingerprint: 'device-fingerprint',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('redeems a trusted offline device token into a fresh JWT pair', async () => {
    devicesRepo.findOne.mockResolvedValue({
      id: 'device-1',
      deviceFingerprint: 'device-fingerprint',
      offlineTokenHash: 'hashed-offline-token',
      tenantId: activeUser.tenantId,
      schoolId: activeUser.schoolId,
      campusId: activeUser.campusId,
      registeredBy: activeUser,
    });
    (bcrypt.compare as jest.Mock).mockResolvedValue(true);
    jwtService.sign
      .mockReturnValueOnce('access-token')
      .mockReturnValueOnce('refresh-token');

    const result = await service.offlineLogin(
      'device-fingerprint',
      'offline-token',
    );

    expect(result.accessToken).toBe('access-token');
    expect(result.refreshToken).toBe('refresh-token');
    expect(devicesRepo.update).toHaveBeenCalledWith(
      'device-1',
      expect.objectContaining({ lastUsedAt: expect.any(Date) }),
    );
    expect(jwtService.sign).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining<Partial<JwtPayload>>({
        tokenType: 'refresh',
        sessionVersion: activeUser.sessionVersion,
        deviceFingerprint: 'device-fingerprint',
      }),
      { expiresIn: '30d' },
    );
  });

  it('rejects refresh when the stored session version has advanced', async () => {
    jwtService.verify.mockReturnValue({
      sub: activeUser.id,
      email: activeUser.email,
      role: activeUser.role,
      tenantId: activeUser.tenantId,
      schoolId: activeUser.schoolId,
      campusId: activeUser.campusId,
      sessionVersion: activeUser.sessionVersion,
      tokenType: 'refresh',
    } satisfies JwtPayload);
    usersRepo.findOne.mockResolvedValue({
      ...activeUser,
      sessionVersion: activeUser.sessionVersion + 1,
    } satisfies User);

    await expect(service.refreshToken('refresh-token-old')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('rejects trusted device login when the device scope no longer matches the user workspace', async () => {
    devicesRepo.findOne.mockResolvedValue({
      id: 'device-1',
      deviceFingerprint: 'device-fingerprint',
      offlineTokenHash: 'hashed-offline-token',
      tenantId: activeUser.tenantId,
      schoolId: 'school-2',
      campusId: activeUser.campusId,
      registeredBy: activeUser,
    });
    (bcrypt.compare as jest.Mock).mockResolvedValue(true);

    await expect(
      service.offlineLogin('device-fingerprint', 'offline-token'),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(devicesRepo.update).not.toHaveBeenCalled();
  });

  it('invalidates the active session version on logout', async () => {
    usersRepo.update.mockResolvedValue(undefined);
    devicesRepo.update.mockResolvedValue(undefined);

    await expect(
      service.logout(activeUser, 'device-fingerprint'),
    ).resolves.toEqual({
      success: true,
      userId: activeUser.id,
      sessionVersion: activeUser.sessionVersion + 1,
    });

    expect(usersRepo.update).toHaveBeenCalledWith(activeUser.id, {
      sessionVersion: activeUser.sessionVersion + 1,
    });
    expect(devicesRepo.update).toHaveBeenCalledWith(
      {
        deviceFingerprint: 'device-fingerprint',
        registeredByUserId: activeUser.id,
        isActive: true,
      },
      expect.objectContaining({ lastUsedAt: expect.any(Date) }),
    );
  });
});
