# DOMAIN MODEL AND ENTITY CATALOG

## Scope hierarchy
- tenant
- school
- campus
- device

## Identity
- User
- Role
- Permission
- Device
- Session
- TrustedDeviceRegistration
- RefreshToken / AuthSession
- AuditEvent

## Academic setup
- AcademicYear
- Term
- ClassLevel
- ClassArm
- Subject
- GradingScheme
- AssessmentType
- ExamDefinition

## People
- Applicant
- Student
- Guardian
- GuardianRelationship
- Enrollment
- Staff
- StaffTeachingAssignment

## Operations
- AttendanceRecord
- ScoreEntry
- ResultSheet
- ReportCard

## Finance
- FeeCategory
- FeeStructure
- StudentFeeAssignment
- Invoice
- InvoiceLine
- Payment
- Receipt
- Reversal
- FinanceLedgerEntry

## Sync / recovery
- SyncQueueItem
- SyncState
- SyncConflict
- SyncPushReceipt
- ChangeLog
- ReconciliationRequest
- BackupArtifact
- RestoreOperation

## Required metadata on sync-backed records
- id
- tenant_id
- school_id
- optional campus_id where entity is campus-bound
- server_revision
- origin_device_id
- lamport_clock
- updated_at
- deleted
