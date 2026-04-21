# Database Design

## Local database
SQLite for local-first operation, scoped per campus installation.

## Cloud database
PostgreSQL for tenant-wide persistence and reporting.

## Core groups
- Identity: users, roles, permissions, devices, sessions
- Academic setup: years, terms, classes, subjects, grading
- People: students, guardians, staff, enrollments
- Operations: attendance, assessments, exams, scores, report cards
- Finance: fee structures, invoices, payments, receipts, reversals
- Sync: queue, sync state, conflicts, change log, idempotency keys
