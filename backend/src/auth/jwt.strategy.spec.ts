import { ConfigService } from '@nestjs/config';
import { UnauthorizedException } from '@nestjs/common';
import { JwtStrategy, JwtPayload } from './jwt.strategy';
import { UserRole } from '../users/user-role.enum';
import { User } from '../users/user.entity';

describe('JwtStrategy', () => {
  const usersRepo = {
    findOne: jest.fn(),
  };

  const config = {
    getOrThrow: jest.fn(),
  } as unknown as ConfigService;

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

  let strategy: JwtStrategy;

  beforeEach(() => {
    jest.resetAllMocks();
    (config.getOrThrow as jest.Mock).mockReturnValue('test-secret');
    strategy = new JwtStrategy(config, usersRepo as never);
  });

  it('accepts access tokens whose scope still matches the user record', async () => {
    usersRepo.findOne.mockResolvedValue(activeUser);

    await expect(strategy.validate(accessPayload())).resolves.toEqual(activeUser);
  });

  it('rejects stale tokens when the stored workspace scope changed', async () => {
    usersRepo.findOne.mockResolvedValue({
      ...activeUser,
      schoolId: 'school-2',
    });

    await expect(strategy.validate(accessPayload())).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('rejects stale tokens when the session version changed', async () => {
    usersRepo.findOne.mockResolvedValue({
      ...activeUser,
      sessionVersion: activeUser.sessionVersion + 1,
    });

    await expect(strategy.validate(accessPayload())).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  function accessPayload(): JwtPayload {
    return {
      sub: activeUser.id,
      email: activeUser.email,
      role: activeUser.role,
      tenantId: activeUser.tenantId,
      schoolId: activeUser.schoolId,
      campusId: activeUser.campusId,
      sessionVersion: activeUser.sessionVersion,
      tokenType: 'access',
    };
  }
});
