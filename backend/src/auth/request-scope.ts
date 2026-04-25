import { ForbiddenException } from '@nestjs/common';
import { User } from '../users/user.entity';

type ScopedUser = Pick<User, 'tenantId' | 'schoolId' | 'campusId'>;

export interface TenantScope {
  tenantId: string;
  schoolId: string | null;
  campusId: string | null;
}

export interface SchoolScope extends TenantScope {
  schoolId: string;
}

export function requireTenantScope(user: ScopedUser): TenantScope {
  if (!user.tenantId) {
    throw new ForbiddenException('Tenant workspace is not assigned to this user.');
  }

  return {
    tenantId: user.tenantId,
    schoolId: user.schoolId,
    campusId: user.campusId,
  };
}

export function requireSchoolScope(user: ScopedUser): SchoolScope {
  const scope = requireTenantScope(user);
  if (!scope.schoolId) {
    throw new ForbiddenException('School workspace is not assigned to this user.');
  }

  return {
    ...scope,
    schoolId: scope.schoolId,
  };
}
