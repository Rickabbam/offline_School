import { ForbiddenException } from '@nestjs/common';
import { requireSchoolScope, requireTenantScope } from './request-scope';

describe('request scope helpers', () => {
  it('returns tenant scope when tenant is assigned', () => {
    expect(
      requireTenantScope({
        tenantId: 'tenant-1',
        schoolId: null,
        campusId: null,
      }),
    ).toEqual({
      tenantId: 'tenant-1',
      schoolId: null,
      campusId: null,
    });
  });

  it('rejects tenant scope when tenant is missing', () => {
    expect(() =>
      requireTenantScope({
        tenantId: null,
        schoolId: 'school-1',
        campusId: null,
      }),
    ).toThrow(ForbiddenException);
  });

  it('returns school scope when tenant and school are assigned', () => {
    expect(
      requireSchoolScope({
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
      }),
    ).toEqual({
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
    });
  });

  it('rejects school scope when school is missing', () => {
    expect(() =>
      requireSchoolScope({
        tenantId: 'tenant-1',
        schoolId: null,
        campusId: null,
      }),
    ).toThrow(ForbiddenException);
  });
});
