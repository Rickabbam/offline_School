# RBAC AND SECURITY SPEC

## Roles from repo docs
- admin
- cashier
- teacher
- parent
- student
- support_technician
- support_admin

## Additional derived implementation roles
- school_admin (maps to admin capabilities at school scope)
- campus_admin (optional future specialization)
- finance_officer (if separated from cashier/admin)
- principal / headteacher (optional reporting-focused preset)

## Enforcement rules
- All permissions enforced server-side
- Client-side guards are advisory only
- Tenant/school/campus scoping must be applied before role checks on data operations
- Cross-campus access requires explicit grants and online verification where documented
- Support impersonation is audited and time-bounded
- Sensitive restore/export operations are audited

## Authentication
- JWT access/refresh tokens
- trusted-device offline token policy
- device-bound refresh behavior
- workstation/device revocation
- first-time login online; subsequent offline access permitted only through trusted device policy

## Security hard requirements
- encrypted backup exports
- environment validation
- secret management
- audit log for critical transitions
