import { ExecutionContext, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolesGuard } from './roles.guard';
import { UserRole } from '../users/user-role.enum';

describe('RolesGuard', () => {
  const handler = function handler() {};
  const controller = class Controller {};

  function contextWithUser(user?: { role: UserRole }): ExecutionContext {
    return {
      getHandler: () => handler,
      getClass: () => controller,
      switchToHttp: () => ({
        getRequest: () => ({ user }),
      }),
    } as unknown as ExecutionContext;
  }

  it('allows requests when no roles metadata is required', () => {
    const reflector = {
      getAllAndOverride: jest.fn().mockReturnValue(undefined),
    } as unknown as Reflector;
    const guard = new RolesGuard(reflector);

    expect(guard.canActivate(contextWithUser())).toBe(true);
  });

  it('allows a user with one of the required roles', () => {
    const reflector = {
      getAllAndOverride: jest
        .fn()
        .mockReturnValue([UserRole.Admin, UserRole.Teacher]),
    } as unknown as Reflector;
    const guard = new RolesGuard(reflector);

    expect(guard.canActivate(contextWithUser({ role: UserRole.Teacher }))).toBe(
      true,
    );
  });

  it('rejects a missing authenticated user before checking roles', () => {
    const reflector = {
      getAllAndOverride: jest.fn().mockReturnValue([UserRole.Admin]),
    } as unknown as Reflector;
    const guard = new RolesGuard(reflector);

    expect(() => guard.canActivate(contextWithUser())).toThrow(
      UnauthorizedException,
    );
  });

  it('rejects a user whose role is not permitted for the action', () => {
    const reflector = {
      getAllAndOverride: jest.fn().mockReturnValue([UserRole.Admin]),
    } as unknown as Reflector;
    const guard = new RolesGuard(reflector);

    expect(() =>
      guard.canActivate(contextWithUser({ role: UserRole.Cashier })),
    ).toThrow(ForbiddenException);
  });
});
