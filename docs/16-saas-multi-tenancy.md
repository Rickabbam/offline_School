# SaaS Multi-Tenancy

## Hierarchy
- Tenant: commercial/account boundary
- School: institutional boundary
- Campus: operational boundary

## Isolation model
- Hard tenant isolation at data and auth layers
- School and campus scoping in all operational queries

## Cross-campus rules
- Access only for authorized roles
- Campus switching requires online authorization
- Local desktop operation remains single-campus scoped by default
