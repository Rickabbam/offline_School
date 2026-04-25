# API AND CONTRACT GUIDELINES

## General rules
- DTOs are source of truth
- OpenAPI generated from DTOs/controllers
- all error responses use structured envelopes
- all sync success receipts return canonical ids and revisions where relevant

## Core endpoint groups
- auth/device registration
- school setup / onboarding
- academic setup
- admissions/students/staff
- attendance
- exams/results/report cards
- finance
- reports
- backup/restore/reconciliation
- sync push/pull/conflicts

## Required response behavior
- consistent validation errors
- consistent forbidden/unauthorized errors
- stale-write conflict payloads
- sync receipt payloads
