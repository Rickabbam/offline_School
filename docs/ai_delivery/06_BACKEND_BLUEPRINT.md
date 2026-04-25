# BACKEND BLUEPRINT — FROM SKELETON TO REAL SERVER

## Current repo state
The repo already contains a NestJS backend skeleton.
This phase expands it into a real business and sync backend.

## Target architecture
- NestJS modular monolith
- PostgreSQL
- Redis for queue/cache/job support
- TypeORM migrations
- DTO validation
- OpenAPI generation from DTOs
- role/permission middleware/guards
- scoped service layer

## Required backend modules
1. config
2. database
3. redis
4. health
5. auth
6. devices
7. tenants
8. schools
9. campuses
10. academic
11. admissions
12. students
13. guardians
14. staff
15. attendance
16. exams
17. finance
18. reports
19. sync
20. backups
21. audit

## Priority build order
1. auth/devices
2. tenants/schools/campuses
3. academic
4. admissions/students/staff
5. attendance
6. finance
7. exams/results
8. reports
9. backups/reconciliation
10. SaaS admin + support tooling

## Backend definition of done
A module is only done when:
- entity + migration exists
- DTOs exist
- service exists
- controller exists
- authorization exists
- tests exist
- sync integration exists if the entity is sync-backed
