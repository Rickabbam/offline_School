import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { AuthService } from './auth.service';
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
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  it('issues distinct access and refresh tokens on login', async () => {
    usersRepo.findOne.mockResolvedValue(activeUser);
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
    expect(jwtService.sign).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining<Partial<JwtPayload>>({
        sub: activeUser.id,
        tokenType: 'access',
      }),
      { expiresIn: '15m' },
    );
    expect(jwtService.sign).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining<Partial<JwtPayload>>({
        sub: activeUser.id,
        tokenType: 'refresh',
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
      tokenType: 'access',
    } satisfies JwtPayload);

    await expect(service.refreshToken('access-token')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(usersRepo.findOne).not.toHaveBeenCalled();
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
    expect(devicesRepo.create).toHaveBeenCalledWith(
      expect.objectContaining({
        deviceName: 'Admin Office PC',
        deviceFingerprint: 'device-fingerprint',
        offlineTokenHash: 'hashed-offline-token',
        registeredByUserId: activeUser.id,
      }),
    );
  });

  it('rejects duplicate device fingerprints', async () => {
    usersRepo.findOne.mockResolvedValue(activeUser);
    devicesRepo.findOne.mockResolvedValue({ id: 'existing-device' });

    await expect(
      service.registerDevice(activeUser.id, {
        deviceName: 'Admin Office PC',
        deviceFingerprint: 'device-fingerprint',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
