import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from "@nestjs/common";
import { DataSource, Repository } from "typeorm";
import {
  AcademicYear,
  ClassArm,
  ClassLevel,
  GradingScheme,
  Subject,
  Term,
} from "../academic/academic.entity";
import { Applicant } from "../admissions/applicant.entity";
import { AttendanceRecord } from "../attendance/attendance-record.entity";
import { AuditService } from "../audit/audit.service";
import { Campus } from "../campuses/campus.entity";
import {
  FeeCategory,
  FeeStructureItem,
  Invoice,
  Payment,
  PaymentReversal,
} from "../finance/finance.entity";
import { School } from "../schools/school.entity";
import { Staff, StaffTeachingAssignment } from "../staff/staff.entity";
import { Enrollment, Guardian, Student } from "../students/student.entity";
import { User } from "../users/user.entity";
import { SyncPushReceipt } from "./sync-push-receipt.entity";
import { SyncReconciliationRequest } from "./sync-reconciliation-request.entity";
import { SyncService } from "./sync.service";

type MockRepo<T extends object> = Partial<
  Record<keyof Repository<T>, jest.Mock>
>;

describe("SyncService", () => {
  let academicYears: MockRepo<AcademicYear>;
  let terms: MockRepo<any>;
  let classLevels: MockRepo<any>;
  let classArms: MockRepo<any>;
  let subjects: MockRepo<any>;
  let schools: MockRepo<School>;
  let campuses: MockRepo<Campus>;
  let gradingSchemes: MockRepo<GradingScheme>;
  let students: MockRepo<Student>;
  let guardians: MockRepo<Guardian>;
  let enrollments: MockRepo<Enrollment>;
  let feeCategories: MockRepo<FeeCategory>;
  let feeStructureItems: MockRepo<FeeStructureItem>;
  let invoices: MockRepo<Invoice>;
  let payments: MockRepo<Payment>;
  let paymentReversals: MockRepo<PaymentReversal>;
  let staff: MockRepo<Staff>;
  let staffAssignments: MockRepo<StaffTeachingAssignment>;
  let applicants: MockRepo<Applicant>;
  let attendance: MockRepo<AttendanceRecord>;
  let receipts: MockRepo<SyncPushReceipt>;
  let reconciliationRequests: MockRepo<SyncReconciliationRequest>;
  let auditService: { record: jest.Mock };
  let dataSource: { transaction: jest.Mock };
  let service: SyncService;

  const campusUser = {
    id: "user-1",
    email: "admin@example.com",
    passwordHash: "hash",
    fullName: "Admin User",
    role: "admin",
    tenantId: "tenant-1",
    schoolId: "school-1",
    campusId: "campus-1",
    isActive: true,
    deleted: false,
    createdAt: new Date("2026-04-22T08:00:00.000Z"),
    updatedAt: new Date("2026-04-22T08:00:00.000Z"),
  } as User;

  beforeEach(() => {
    academicYears = { find: jest.fn() };
    terms = { find: jest.fn() };
    classLevels = { find: jest.fn() };
    classArms = { find: jest.fn() };
    subjects = { find: jest.fn() };
    schools = { find: jest.fn(), save: jest.fn(), create: jest.fn() };
    campuses = { find: jest.fn(), save: jest.fn(), create: jest.fn() };
    gradingSchemes = { find: jest.fn(), save: jest.fn(), create: jest.fn() };
    students = { find: jest.fn(), save: jest.fn(), create: jest.fn() };
    guardians = { find: jest.fn(), save: jest.fn(), create: jest.fn() };
    enrollments = { find: jest.fn(), save: jest.fn(), create: jest.fn() };
    feeCategories = { find: jest.fn(), save: jest.fn(), create: jest.fn() };
    feeStructureItems = { find: jest.fn(), save: jest.fn(), create: jest.fn() };
    invoices = { find: jest.fn(), save: jest.fn(), create: jest.fn() };
    payments = {
      find: jest.fn(),
      findOne: jest.fn(),
      save: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    };
    paymentReversals = {
      find: jest.fn(),
      findOne: jest.fn(),
      save: jest.fn(),
      create: jest.fn(),
    };
    staff = { find: jest.fn(), save: jest.fn(), create: jest.fn() };
    staffAssignments = { find: jest.fn(), save: jest.fn(), create: jest.fn() };
    applicants = { find: jest.fn(), save: jest.fn(), create: jest.fn() };
    attendance = { find: jest.fn(), save: jest.fn(), create: jest.fn() };
    receipts = { findOne: jest.fn() };
    reconciliationRequests = {
      create: jest.fn(),
      save: jest.fn(),
      findOne: jest.fn(),
      update: jest.fn(),
    };
    auditService = { record: jest.fn() };
    dataSource = { transaction: jest.fn() };

    service = new SyncService(
      dataSource as unknown as DataSource,
      academicYears as unknown as Repository<AcademicYear>,
      terms as unknown as Repository<any>,
      classLevels as unknown as Repository<any>,
      classArms as unknown as Repository<any>,
      subjects as unknown as Repository<any>,
      schools as unknown as Repository<School>,
      campuses as unknown as Repository<Campus>,
      gradingSchemes as unknown as Repository<GradingScheme>,
      students as unknown as Repository<Student>,
      guardians as unknown as Repository<Guardian>,
      enrollments as unknown as Repository<Enrollment>,
      feeCategories as unknown as Repository<FeeCategory>,
      feeStructureItems as unknown as Repository<FeeStructureItem>,
      invoices as unknown as Repository<Invoice>,
      payments as unknown as Repository<Payment>,
      paymentReversals as unknown as Repository<PaymentReversal>,
      staff as unknown as Repository<Staff>,
      staffAssignments as unknown as Repository<StaffTeachingAssignment>,
      applicants as unknown as Repository<Applicant>,
      attendance as unknown as Repository<AttendanceRecord>,
      receipts as unknown as Repository<SyncPushReceipt>,
      reconciliationRequests as unknown as Repository<SyncReconciliationRequest>,
      auditService as unknown as AuditService,
    );
  });

  it("creates a reconciliation request scoped to the authenticated school and campus", async () => {
    const request = {
      id: "reconcile-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      campusId: "campus-1",
      targetDeviceId: "device-1",
      reason: "manual_support_reconcile",
      status: "pending",
      requestedByUserId: "user-1",
      acknowledgedByUserId: null,
      requestedAt: new Date("2026-04-22T10:00:00.000Z"),
      acknowledgedAt: null,
      createdAt: new Date("2026-04-22T10:00:00.000Z"),
      updatedAt: new Date("2026-04-22T10:00:00.000Z"),
    } as SyncReconciliationRequest;
    reconciliationRequests.create!.mockImplementation((value) => value);
    reconciliationRequests.save!.mockResolvedValue(request);

    const result = await service.createReconciliationRequest(campusUser, {
      target_device_id: "device-1",
    });

    expect(reconciliationRequests.create).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        targetDeviceId: "device-1",
        reason: "manual_support_reconcile",
        status: "pending",
      }),
    );
    expect(auditService.record).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        actorUserId: "user-1",
        eventType: "sync.reconciliation_requested",
        entityType: "sync_reconciliation_request",
        entityId: "reconcile-1",
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        id: "reconcile-1",
        campusId: "campus-1",
        targetDeviceId: "device-1",
        status: "pending",
      }),
    );
  });

  it("rejects support technician reconciliation requests outside the active campus", async () => {
    const technicianUser = {
      ...campusUser,
      role: "support_technician",
    } as User;

    await expect(
      service.createReconciliationRequest(technicianUser, {
        target_device_id: "device-1",
        campus_id: "campus-2",
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(reconciliationRequests.save).not.toHaveBeenCalled();
    expect(auditService.record).not.toHaveBeenCalled();
  });

  it("rejects sync pull for support technicians before any data is read", async () => {
    const technicianUser = {
      ...campusUser,
      role: "support_technician",
    } as User;

    await expect(
      service.pull(technicianUser, "student", 0),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(students.find).not.toHaveBeenCalled();
  });

  it("rejects sync push for support technicians before any mutation is attempted", async () => {
    const technicianUser = {
      ...campusUser,
      role: "support_technician",
    } as User;

    await expect(
      service.push(technicianUser, {
        idempotency_key: "idem-tech-1",
        entity_type: "student",
        entity_id: "student-1",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
          firstName: "Ama",
          lastName: "Mensah",
          status: "active",
        },
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(dataSource.transaction).not.toHaveBeenCalled();
  });

  it("rejects teacher finance sync before any data is read", async () => {
    const teacherUser = {
      ...campusUser,
      role: "teacher",
    } as User;

    await expect(
      service.pull(teacherUser, "payment", 0),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(payments.find).not.toHaveBeenCalled();
  });

  it("rejects cashier staff sync before any mutation is attempted", async () => {
    const cashierUser = {
      ...campusUser,
      role: "cashier",
    } as User;

    await expect(
      service.push(cashierUser, {
        idempotency_key: "idem-cashier-staff-1",
        entity_type: "staff",
        entity_id: "staff-1",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
          firstName: "Akosua",
          lastName: "Owusu",
          status: "active",
        },
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(dataSource.transaction).not.toHaveBeenCalled();
  });

  it("allows cashier finance sync through to scoped reads", async () => {
    const cashierUser = {
      ...campusUser,
      role: "cashier",
    } as User;
    payments.find!.mockResolvedValue([]);

    await expect(service.pull(cashierUser, "payment", 0)).resolves.toEqual({
      records: [],
      latest_revision: 0,
      has_more: false,
      next_since: 0,
    });
    expect(payments.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
        }),
      }),
    );
  });

  it("rejects reconciliation request lookup for parent accounts", async () => {
    const parentUser = {
      ...campusUser,
      role: "parent",
    } as User;

    await expect(
      service.getPendingReconciliationRequest(parentUser, "device-1"),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(reconciliationRequests.findOne).not.toHaveBeenCalled();
  });

  it("returns an existing pending reconciliation request on scoped unique replay", async () => {
    const pending = {
      id: "reconcile-existing-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      campusId: "campus-1",
      targetDeviceId: "device-1",
      reason: "network_recovery",
      status: "pending",
      requestedByUserId: "user-1",
      acknowledgedByUserId: null,
      requestedAt: new Date("2026-04-22T11:00:00.000Z"),
      acknowledgedAt: null,
      createdAt: new Date("2026-04-22T11:00:00.000Z"),
      updatedAt: new Date("2026-04-22T11:00:00.000Z"),
    } as SyncReconciliationRequest;
    reconciliationRequests.create!.mockImplementation((value) => value);
    reconciliationRequests.save!.mockRejectedValue({
      driverError: {
        code: "23505",
        constraint: "idx_sync_reconciliation_requests_target_pending",
      },
    });
    reconciliationRequests.findOne!.mockResolvedValue(pending);

    const result = await service.createReconciliationRequest(campusUser, {
      target_device_id: "device-1",
      reason: "network_recovery",
    });

    expect(reconciliationRequests.findOne).toHaveBeenCalledWith({
      where: {
        tenantId: "tenant-1",
        schoolId: "school-1",
        targetDeviceId: "device-1",
        status: "pending",
      },
      order: {
        requestedAt: "DESC",
      },
    });
    expect(result).toEqual(
      expect.objectContaining({
        id: "reconcile-existing-1",
        targetDeviceId: "device-1",
        status: "pending",
      }),
    );
  });

  it("returns only the pending reconciliation request for the current device scope", async () => {
    reconciliationRequests.findOne!.mockResolvedValue({
      id: "reconcile-current-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      campusId: "campus-1",
      targetDeviceId: "device-1",
      reason: "manual_support_reconcile",
      status: "pending",
      requestedByUserId: "user-1",
      acknowledgedByUserId: null,
      requestedAt: new Date("2026-04-22T12:00:00.000Z"),
      acknowledgedAt: null,
      createdAt: new Date("2026-04-22T12:00:00.000Z"),
      updatedAt: new Date("2026-04-22T12:00:00.000Z"),
    } as SyncReconciliationRequest);

    const result = await service.getPendingReconciliationRequest(
      campusUser,
      "device-1",
    );

    expect(reconciliationRequests.findOne).toHaveBeenCalledWith({
      where: {
        tenantId: "tenant-1",
        schoolId: "school-1",
        targetDeviceId: "device-1",
        status: "pending",
        campusId: "campus-1",
      },
      order: {
        requestedAt: "DESC",
      },
    });
    expect(result).toEqual({
      request: expect.objectContaining({
        id: "reconcile-current-1",
        targetDeviceId: "device-1",
      }),
    });
  });

  it("acknowledges a pending reconciliation request only within the active device scope", async () => {
    reconciliationRequests.findOne!.mockResolvedValue({
      id: "reconcile-ack-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      campusId: "campus-1",
      targetDeviceId: "device-1",
      reason: "manual_support_reconcile",
      status: "pending",
      requestedByUserId: "user-2",
      acknowledgedByUserId: null,
      requestedAt: new Date("2026-04-22T13:00:00.000Z"),
      acknowledgedAt: null,
      createdAt: new Date("2026-04-22T13:00:00.000Z"),
      updatedAt: new Date("2026-04-22T13:00:00.000Z"),
    } as SyncReconciliationRequest);

    const result = await service.acknowledgeReconciliationRequest(
      campusUser,
      "reconcile-ack-1",
      "device-1",
    );

    expect(reconciliationRequests.findOne).toHaveBeenCalledWith({
      where: {
        tenantId: "tenant-1",
        schoolId: "school-1",
        targetDeviceId: "device-1",
        status: "pending",
        campusId: "campus-1",
        id: "reconcile-ack-1",
      },
    });
    expect(reconciliationRequests.update).toHaveBeenCalledWith(
      "reconcile-ack-1",
      expect.objectContaining({
        status: "applied",
        acknowledgedByUserId: "user-1",
        acknowledgedAt: expect.any(Date),
      }),
    );
    expect(auditService.record).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        actorUserId: "user-1",
        eventType: "sync.reconciliation_acknowledged",
        entityType: "sync_reconciliation_request",
        entityId: "reconcile-ack-1",
      }),
    );
    expect(result).toEqual({
      acknowledged: true,
      requestId: "reconcile-ack-1",
    });
  });

  it("returns the stored response when a sync push is replayed with the same idempotency key", async () => {
    const responsePayload = {
      status: "accepted",
      entityType: "student",
      entityId: "student-1",
      serverRevision: 100,
      operation: "create",
    };
    dataSource.transaction.mockRejectedValue({
      driverError: {
        code: "23505",
        constraint: "idx_sync_push_receipts_idempotency_scope",
      },
      name: "QueryFailedError",
    });
    receipts.findOne!.mockResolvedValue({
      id: "receipt-1",
      idempotencyKey: "idem-1",
      userId: campusUser.id,
      tenantId: campusUser.tenantId,
      schoolId: campusUser.schoolId,
      campusId: campusUser.campusId,
      originDeviceId: "device-fingerprint-1",
      lamportClock: 7,
      entityType: "student",
      entityId: "student-1",
      canonicalEntityId: "student-1",
      operation: "create",
      serverRevision: 100,
      requestPayloadHash: null,
      responsePayload,
      completedAt: new Date("2026-04-22T10:00:00.000Z"),
      createdAt: new Date(),
      updatedAt: new Date(),
    } as SyncPushReceipt);

    const result = await service.push(campusUser, {
      idempotency_key: "idem-1",
      entity_type: "student",
      entity_id: "student-1",
      operation: "create",
      payload: {
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        firstName: "Ama",
        lastName: "Mensah",
        status: "active",
      },
    });

    expect(receipts.findOne).toHaveBeenCalledWith({
      where: {
        idempotencyKey: "idem-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        userId: "user-1",
      },
    });
    expect(result).toEqual(responsePayload);
  });

  it("rejects idempotency replay when the stored request does not match the new request", async () => {
    dataSource.transaction.mockRejectedValue({
      driverError: {
        code: "23505",
        constraint: "idx_sync_push_receipts_idempotency_scope",
      },
      name: "QueryFailedError",
    });
    receipts.findOne!.mockResolvedValue({
      id: "receipt-1",
      idempotencyKey: "idem-mismatch-1",
      userId: campusUser.id,
      tenantId: campusUser.tenantId,
      schoolId: campusUser.schoolId,
      campusId: campusUser.campusId,
      originDeviceId: "device-fingerprint-1",
      lamportClock: 7,
      entityType: "student",
      entityId: "student-original",
      canonicalEntityId: "student-original",
      operation: "create",
      serverRevision: 99,
      requestPayloadHash: "different-hash",
      responsePayload: {
        status: "accepted",
        entityType: "student",
        entityId: "student-original",
        operation: "create",
      },
      completedAt: new Date("2026-04-22T10:00:00.000Z"),
      createdAt: new Date(),
      updatedAt: new Date(),
    } as SyncPushReceipt);

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-mismatch-1",
        entity_type: "student",
        entity_id: "student-1",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
          firstName: "Ama",
          lastName: "Mensah",
          status: "active",
        },
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it("rejects idempotency replay when the original receipt is not completed", async () => {
    dataSource.transaction.mockRejectedValue({
      driverError: {
        code: "23505",
        constraint: "idx_sync_push_receipts_idempotency_scope",
      },
      name: "QueryFailedError",
    });
    receipts.findOne!.mockResolvedValue({
      id: "receipt-incomplete-1",
      idempotencyKey: "idem-incomplete-1",
      userId: campusUser.id,
      tenantId: campusUser.tenantId,
      schoolId: campusUser.schoolId,
      campusId: campusUser.campusId,
      originDeviceId: "device-fingerprint-1",
      lamportClock: 7,
      entityType: "student",
      entityId: "student-1",
      canonicalEntityId: null,
      operation: "create",
      serverRevision: null,
      requestPayloadHash: null,
      responsePayload: {},
      completedAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    } as SyncPushReceipt);

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-incomplete-1",
        entity_type: "student",
        entity_id: "student-1",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
          firstName: "Ama",
          lastName: "Mensah",
          status: "active",
        },
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it("reconstructs idempotency replay from canonical receipt fields when response payload is missing", async () => {
    dataSource.transaction.mockRejectedValue({
      driverError: {
        code: "23505",
        constraint: "idx_sync_push_receipts_idempotency_scope",
      },
      name: "QueryFailedError",
    });
    receipts.findOne!.mockResolvedValue({
      id: "receipt-canonical-1",
      idempotencyKey: "idem-canonical-1",
      userId: campusUser.id,
      tenantId: campusUser.tenantId,
      schoolId: campusUser.schoolId,
      campusId: campusUser.campusId,
      originDeviceId: "device-fingerprint-1",
      lamportClock: 7,
      entityType: "enrollment",
      entityId: "device-enrollment-9",
      canonicalEntityId: "enrollment-server-1",
      operation: "create",
      serverRevision: 103,
      requestPayloadHash: null,
      responsePayload: {},
      completedAt: new Date("2026-04-22T10:00:00.000Z"),
      createdAt: new Date(),
      updatedAt: new Date(),
    } as SyncPushReceipt);

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-canonical-1",
        entity_type: "enrollment",
        entity_id: "device-enrollment-9",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          studentId: "student-1",
          classArmId: "arm-1",
          academicYearId: "year-1",
          enrollmentDate: "2026-04-22",
        },
      }),
    ).resolves.toEqual({
      status: "accepted",
      entityType: "enrollment",
      entityId: "enrollment-server-1",
      serverRevision: 103,
      operation: "create",
    });
  });

  it("does not treat domain unique violations as idempotency replays", async () => {
    const domainUniqueError = {
      driverError: {
        code: "23505",
        constraint: "uq_enrollments_active_student_year",
      },
      name: "QueryFailedError",
    };
    dataSource.transaction.mockRejectedValue(domainUniqueError);

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-domain-unique-1",
        entity_type: "enrollment",
        entity_id: "enrollment-1",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          studentId: "student-1",
          classArmId: "arm-1",
          academicYearId: "year-1",
          enrollmentDate: "2026-04-22",
        },
      }),
    ).rejects.toBe(domainUniqueError);
    expect(receipts.findOne).not.toHaveBeenCalled();
  });

  it("persists origin device provenance with the sync push receipt", async () => {
    const studentRepo = {
      findOne: jest
        .fn()
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({
          id: "student-1",
          serverRevision: 100,
          updatedAt: new Date("2026-04-22T10:00:00.000Z"),
        }),
      save: jest.fn(),
      create: jest.fn((value: unknown) => value),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest
        .fn()
        .mockResolvedValueOnce({
          id: "receipt-1",
        })
        .mockResolvedValueOnce(undefined),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "100" }]),
      getRepository: jest.fn(() => studentRepo),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    const result = await service.push(campusUser, {
      idempotency_key: "idem-origin-1",
      origin_device_id: "device-fingerprint-1",
      lamport_clock: 42,
      entity_type: "student",
      entity_id: "student-1",
      operation: "create",
      payload: {
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        firstName: "Ama",
        lastName: "Mensah",
        status: "active",
      },
    });

    expect(manager.create).toHaveBeenCalledWith(
      SyncPushReceipt,
      expect.objectContaining({
        originDeviceId: "device-fingerprint-1",
        lamportClock: 42,
        requestPayloadHash: expect.any(String),
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        entityId: "student-1",
        serverRevision: 100,
      }),
    );
    expect(manager.update).toHaveBeenCalledWith(SyncPushReceipt, "receipt-1", {
      canonicalEntityId: "student-1",
      serverRevision: 100,
      responsePayload: expect.objectContaining({
        entityId: "student-1",
        serverRevision: 100,
      }),
      completedAt: expect.any(Date),
    });
  });

  it("records an audit entry for accepted sync push mutations in the same transaction", async () => {
    const studentRepo = {
      findOne: jest
        .fn()
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({
          id: "student-1",
          serverRevision: 101,
          updatedAt: new Date("2026-04-22T10:00:00.000Z"),
        }),
      save: jest.fn(),
      create: jest.fn((value: unknown) => value),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "101" }]),
      getRepository: jest.fn(() => studentRepo),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await service.push(campusUser, {
      idempotency_key: "idem-audit-1",
      origin_device_id: "device-fingerprint-1",
      lamport_clock: 12,
      entity_type: "student",
      entity_id: "student-1",
      operation: "create",
      payload: {
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        firstName: "Ama",
        lastName: "Mensah",
        status: "active",
      },
    });

    expect(auditService.record).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        actorUserId: "user-1",
        eventType: "sync.student.create",
        entityType: "student",
        entityId: "student-1",
        metadata: expect.objectContaining({
          idempotencyKey: "idem-audit-1",
          originDeviceId: "device-fingerprint-1",
          lamportClock: 12,
          operation: "create",
          receiptId: "receipt-1",
          serverRevision: 101,
        }),
      }),
      manager,
    );
    expect(manager.update).toHaveBeenCalledWith(SyncPushReceipt, "receipt-1", {
      canonicalEntityId: "student-1",
      serverRevision: 101,
      responsePayload: expect.objectContaining({
        entityId: "student-1",
        serverRevision: 101,
      }),
      completedAt: expect.any(Date),
    });
  });

  it("pushes academic setup records with server revisions for offline onboarding", async () => {
    const academicYearRepo = {
      findOne: jest
        .fn()
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({
          id: "year-1",
          tenantId: "tenant-1",
          schoolId: "school-1",
          serverRevision: 115,
          updatedAt: new Date("2026-04-22T10:00:00.000Z"),
        }),
      save: jest.fn(),
      create: jest.fn((value: unknown) => value),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "115" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === AcademicYear) {
          return academicYearRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-academic-year-1",
        origin_device_id: "device-fingerprint-1",
        entity_type: "academic_year",
        entity_id: "year-1",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          label: "2026/2027",
          startDate: "2026-09-01",
          endDate: "2027-07-31",
          isCurrent: true,
        },
      }),
    ).resolves.toEqual({
      status: "accepted",
      entityType: "academic_year",
      entityId: "year-1",
      serverRevision: 115,
      operation: "create",
    });
    expect(academicYearRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: "year-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        label: "2026/2027",
        serverRevision: 115,
      }),
    );
  });

  it("rejects academic term sync when the academic year belongs to another school", async () => {
    const termRepo = {
      findOne: jest.fn().mockResolvedValue(null),
      save: jest.fn(),
      create: jest.fn((value: unknown) => value),
    };
    const academicYearRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "year-2",
        tenantId: "tenant-1",
        schoolId: "school-2",
        deleted: false,
      }),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "116" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === Term) {
          return termRepo;
        }
        if (entity === AcademicYear) {
          return academicYearRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-term-cross-school-1",
        entity_type: "term",
        entity_id: "term-1",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          academicYearId: "year-2",
          name: "Term 1",
          termNumber: 1,
          startDate: "2026-09-01",
          endDate: "2026-12-18",
        },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(termRepo.save).not.toHaveBeenCalled();
    expect(auditService.record).not.toHaveBeenCalled();
  });

  it("rejects stale sync updates when the server record is newer than the client base timestamp", async () => {
    const studentRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "student-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        updatedAt: new Date("2026-04-22T12:00:00.000Z"),
      }),
      save: jest.fn(),
      create: jest.fn((value) => value),
      update: jest.fn(),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn(),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "102" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === Student) {
          return studentRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-stale-1",
        entity_type: "student",
        entity_id: "student-1",
        operation: "update",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
          firstName: "Ama",
          lastName: "Mensah",
          status: "active",
          baseUpdatedAt: "2026-04-22T10:00:00.000Z",
        },
      }),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        code: "sync_conflict",
        conflictType: "stale_update",
        entityType: "student",
        entityId: "student-1",
        baseUpdatedAt: "2026-04-22T10:00:00.000Z",
        serverUpdatedAt: "2026-04-22T12:00:00.000Z",
      }),
    });
  });

  it("rejects stale sync updates when the server revision is newer than the client base revision", async () => {
    const studentRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "student-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        serverRevision: 15,
        updatedAt: new Date("2026-04-22T10:00:00.000Z"),
      }),
      save: jest.fn(),
      create: jest.fn((value) => value),
      update: jest.fn(),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn(),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "109" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === Student) {
          return studentRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-stale-revision-1",
        entity_type: "student",
        entity_id: "student-1",
        operation: "update",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
          firstName: "Ama",
          lastName: "Mensah",
          status: "active",
          baseServerRevision: 14,
        },
      }),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        code: "sync_conflict",
        conflictType: "stale_update",
        entityType: "student",
        entityId: "student-1",
        baseServerRevision: 14,
        serverRevision: 15,
      }),
    });
    expect(auditService.record).not.toHaveBeenCalled();
  });

  it("rejects sync updates with invalid base server revision metadata", async () => {
    const studentRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "student-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        updatedAt: new Date("2026-04-22T10:00:00.000Z"),
      }),
      save: jest.fn(),
      create: jest.fn((value) => value),
      update: jest.fn(),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn(),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "110" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === Student) {
          return studentRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-invalid-revision-1",
        entity_type: "student",
        entity_id: "student-1",
        operation: "update",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
          firstName: "Ama",
          lastName: "Mensah",
          status: "active",
          baseServerRevision: "not-a-number",
        },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(auditService.record).not.toHaveBeenCalled();
  });

  it("rejects push when a campus-scoped payload targets a different campus", async () => {
    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-1",
        entity_type: "student",
        entity_id: "student-1",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-2",
          firstName: "Ama",
          lastName: "Mensah",
          status: "active",
        },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it("rejects school-wide sync create when the payload campus belongs to another school", async () => {
    const schoolWideUser = {
      ...campusUser,
      campusId: null,
    } as User;
    const studentRepo = {
      findOne: jest.fn().mockResolvedValue(null),
    };
    const campusRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "campus-2",
        tenantId: "tenant-1",
        schoolId: "school-2",
        deleted: false,
      }),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "114" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === Student) {
          return studentRepo;
        }
        if (entity === Campus) {
          return campusRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(schoolWideUser, {
        idempotency_key: "idem-cross-campus-create-1",
        entity_type: "student",
        entity_id: "student-1",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-2",
          firstName: "Ama",
          lastName: "Mensah",
          status: "active",
        },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(auditService.record).not.toHaveBeenCalled();
  });

  it("rejects sync update when the target row belongs to another tenant", async () => {
    const studentRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "student-1",
        tenantId: "tenant-2",
        schoolId: "school-1",
        campusId: "campus-1",
      }),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "111" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === Student) {
          return studentRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-target-scope-1",
        entity_type: "student",
        entity_id: "student-1",
        operation: "update",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
          firstName: "Ama",
          lastName: "Mensah",
          status: "active",
        },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(auditService.record).not.toHaveBeenCalled();
  });

  it("rejects sync delete when the target row is missing", async () => {
    const studentRepo = {
      findOne: jest.fn().mockResolvedValue(null),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "112" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === Student) {
          return studentRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-target-missing-1",
        entity_type: "student",
        entity_id: "missing-student",
        operation: "delete",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
        },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(auditService.record).not.toHaveBeenCalled();
  });

  it("rejects sync create when the target row already exists", async () => {
    const studentRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "student-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        serverRevision: 20,
      }),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "113" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === Student) {
          return studentRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-duplicate-create-1",
        entity_type: "student",
        entity_id: "student-1",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
          firstName: "Ama",
          lastName: "Mensah",
          status: "active",
        },
      }),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        code: "sync_conflict",
        conflictType: "duplicate_create",
        entityType: "student",
        entityId: "student-1",
      }),
    });
    expect(auditService.record).not.toHaveBeenCalled();
  });

  it("reuses the existing enrollment when sync receives the same student-year with a new device id", async () => {
    const studentRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "student-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
      }),
    };
    const classArmRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "arm-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
      }),
    };
    const academicYearRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "year-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
      }),
    };
    const enrollmentRepo = {
      findOne: jest
        .fn()
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({
          id: "enrollment-server-1",
          tenantId: "tenant-1",
          schoolId: "school-1",
          studentId: "student-1",
          academicYearId: "year-1",
          deleted: false,
        })
        .mockResolvedValueOnce({
          id: "enrollment-server-1",
          serverRevision: 103,
          updatedAt: new Date("2026-04-22T10:00:00.000Z"),
        }),
      save: jest.fn(),
      create: jest.fn((value) => value),
      update: jest.fn(),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "103" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === Student) {
          return studentRepo;
        }
        if (entity === ClassArm) {
          return classArmRepo;
        }
        if (entity === AcademicYear) {
          return academicYearRepo;
        }
        if (entity === Enrollment) {
          return enrollmentRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    const result = await service.push(campusUser, {
      idempotency_key: "idem-enrollment-natural-1",
      entity_type: "enrollment",
      entity_id: "device-enrollment-9",
      operation: "create",
      payload: {
        tenantId: "tenant-1",
        schoolId: "school-1",
        studentId: "student-1",
        classArmId: "arm-1",
        academicYearId: "year-1",
        enrollmentDate: "2026-04-22",
      },
    });

    expect(enrollmentRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: "enrollment-server-1",
        studentId: "student-1",
        academicYearId: "year-1",
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        entityId: "enrollment-server-1",
        requestedEntityId: "device-enrollment-9",
        serverRevision: 103,
      }),
    );
    expect(manager.update).toHaveBeenCalledWith(SyncPushReceipt, "receipt-1", {
      canonicalEntityId: "enrollment-server-1",
      serverRevision: 103,
      responsePayload: expect.objectContaining({
        entityId: "enrollment-server-1",
        requestedEntityId: "device-enrollment-9",
        serverRevision: 103,
      }),
      completedAt: expect.any(Date),
    });
  });

  it("reuses the existing attendance record when sync receives the same student-class-date with a new device id", async () => {
    const studentRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "student-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
      }),
    };
    const classArmRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "arm-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
      }),
    };
    const academicYearRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "year-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
      }),
    };
    const termRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "term-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
      }),
    };
    const attendanceRepo = {
      findOne: jest
        .fn()
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({
          id: "attendance-server-1",
          tenantId: "tenant-1",
          schoolId: "school-1",
          studentId: "student-1",
          classArmId: "arm-1",
          attendanceDate: "2026-04-22",
          updatedAt: new Date("2026-04-22T10:00:00.000Z"),
          deleted: false,
        })
        .mockResolvedValueOnce({
          id: "attendance-server-1",
          serverRevision: 104,
          updatedAt: new Date("2026-04-22T10:00:00.000Z"),
        }),
      save: jest.fn(),
      create: jest.fn((value) => value),
      update: jest.fn(),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "104" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === Student) {
          return studentRepo;
        }
        if (entity === ClassArm) {
          return classArmRepo;
        }
        if (entity === AcademicYear) {
          return academicYearRepo;
        }
        if (entity === Term) {
          return termRepo;
        }
        if (entity === AttendanceRecord) {
          return attendanceRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    const result = await service.push(campusUser, {
      idempotency_key: "idem-attendance-natural-1",
      entity_type: "attendance_record",
      entity_id: "device-attendance-9",
      operation: "create",
      payload: {
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        studentId: "student-1",
        classArmId: "arm-1",
        academicYearId: "year-1",
        termId: "term-1",
        attendanceDate: "2026-04-22",
        status: "present",
        recordedByUserId: "user-1",
      },
    });

    expect(attendanceRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: "attendance-server-1",
        studentId: "student-1",
        classArmId: "arm-1",
        attendanceDate: "2026-04-22",
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        entityId: "attendance-server-1",
        requestedEntityId: "device-attendance-9",
        serverRevision: 104,
      }),
    );
    expect(manager.update).toHaveBeenCalledWith(SyncPushReceipt, "receipt-1", {
      canonicalEntityId: "attendance-server-1",
      serverRevision: 104,
      responsePayload: expect.objectContaining({
        entityId: "attendance-server-1",
        requestedEntityId: "device-attendance-9",
        serverRevision: 104,
      }),
      completedAt: expect.any(Date),
    });
  });

  it("does not reuse attendance from another campus when sync receives the same student-class-date", async () => {
    const studentRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "student-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
      }),
    };
    const classArmRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "arm-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
      }),
    };
    const academicYearRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "year-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
      }),
    };
    const termRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "term-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
      }),
    };
    const attendanceRepo = {
      findOne: jest
        .fn()
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({
          id: "device-attendance-10",
          serverRevision: 105,
          updatedAt: new Date("2026-04-22T10:00:00.000Z"),
        }),
      save: jest.fn(),
      create: jest.fn((value) => value),
      update: jest.fn(),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "105" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === Student) {
          return studentRepo;
        }
        if (entity === ClassArm) {
          return classArmRepo;
        }
        if (entity === AcademicYear) {
          return academicYearRepo;
        }
        if (entity === Term) {
          return termRepo;
        }
        if (entity === AttendanceRecord) {
          return attendanceRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    const result = await service.push(campusUser, {
      idempotency_key: "idem-attendance-campus-1",
      entity_type: "attendance_record",
      entity_id: "device-attendance-10",
      operation: "create",
      payload: {
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        studentId: "student-1",
        classArmId: "arm-1",
        academicYearId: "year-1",
        termId: "term-1",
        attendanceDate: "2026-04-22",
        status: "present",
        recordedByUserId: "user-1",
      },
    });

    expect(attendanceRepo.findOne).toHaveBeenNthCalledWith(3, {
      where: {
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        studentId: "student-1",
        classArmId: "arm-1",
        attendanceDate: "2026-04-22",
        deleted: false,
      },
    });
    expect(attendanceRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: "device-attendance-10",
        campusId: "campus-1",
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        entityId: "device-attendance-10",
        requestedEntityId: undefined,
        serverRevision: 105,
      }),
    );
  });

  it("rejects guardian sync when the referenced student belongs to another campus", async () => {
    const studentRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "student-2",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-2",
      }),
    };
    const guardianRepo = {
      findOne: jest.fn().mockResolvedValue(null),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "105" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === Guardian) {
          return guardianRepo;
        }
        if (entity === Student) {
          return studentRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-guardian-scope-1",
        entity_type: "guardian",
        entity_id: "guardian-1",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          studentId: "student-2",
          firstName: "Kojo",
          lastName: "Mensah",
          relationship: "father",
        },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(auditService.record).not.toHaveBeenCalled();
  });

  it("rejects staff assignment sync when the referenced staff member belongs to another campus", async () => {
    const staffRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "staff-2",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-2",
      }),
    };
    const staffAssignmentRepo = {
      findOne: jest.fn().mockResolvedValue(null),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "106" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === StaffTeachingAssignment) {
          return staffAssignmentRepo;
        }
        if (entity === Staff) {
          return staffRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-staff-assignment-scope-1",
        entity_type: "staff_teaching_assignment",
        entity_id: "assignment-1",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          staffId: "staff-2",
          assignmentType: "class_teacher",
          classArmId: "arm-1",
        },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(auditService.record).not.toHaveBeenCalled();
  });

  it("rejects enrollment sync when the referenced class arm belongs to another school", async () => {
    const studentRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "student-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
      }),
    };
    const classArmRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "arm-2",
        tenantId: "tenant-1",
        schoolId: "school-2",
      }),
    };
    const enrollmentRepo = {
      findOne: jest.fn().mockResolvedValue(null),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "107" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === Enrollment) {
          return enrollmentRepo;
        }
        if (entity === Student) {
          return studentRepo;
        }
        if (entity === ClassArm) {
          return classArmRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-enrollment-class-scope-1",
        entity_type: "enrollment",
        entity_id: "enrollment-1",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          studentId: "student-1",
          classArmId: "arm-2",
          academicYearId: "year-1",
          enrollmentDate: "2026-04-22",
        },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(auditService.record).not.toHaveBeenCalled();
  });

  it("rejects staff assignment sync when the referenced subject belongs to another school", async () => {
    const staffRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "staff-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
      }),
    };
    const subjectRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "subject-2",
        tenantId: "tenant-1",
        schoolId: "school-2",
      }),
    };
    const staffAssignmentRepo = {
      findOne: jest.fn().mockResolvedValue(null),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "108" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === StaffTeachingAssignment) {
          return staffAssignmentRepo;
        }
        if (entity === Staff) {
          return staffRepo;
        }
        if (entity === Subject) {
          return subjectRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-staff-subject-scope-1",
        entity_type: "staff_teaching_assignment",
        entity_id: "assignment-1",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          staffId: "staff-1",
          assignmentType: "subject_teacher",
          subjectId: "subject-2",
        },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(auditService.record).not.toHaveBeenCalled();
  });

  it("pulls campus-scoped student records only for the active campus", async () => {
    const row = {
      id: "student-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      campusId: "campus-1",
      firstName: "Ama",
      lastName: "Mensah",
      serverRevision: 25,
      createdAt: new Date("2026-04-22T09:00:00.000Z"),
      updatedAt: new Date("2026-04-22T10:00:00.000Z"),
    } as Student;
    students.find!.mockResolvedValue([row]);

    const result = await service.pull(campusUser, "student", 0);

    expect(students.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
        }),
        take: 501,
      }),
    );
    expect(result.records).toHaveLength(1);
    expect(result).toEqual(
      expect.objectContaining({
        has_more: false,
        latest_revision: 25,
        next_since: 25,
      }),
    );
    expect(result.records[0]).toEqual(
      expect.objectContaining({
        entity_type: "student",
        revision: 25,
        record: expect.objectContaining({
          id: "student-1",
          campusId: "campus-1",
        }),
      }),
    );
  });

  it("rejects pull requests with an invalid revision cursor", async () => {
    await expect(
      service.pull(campusUser, "student", -1),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(students.find).not.toHaveBeenCalled();
  });

  it("returns bounded pull pages with a continuation cursor", async () => {
    students.find!.mockResolvedValue([
      {
        id: "student-11",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        firstName: "First",
        lastName: "Student",
        serverRevision: 11,
        createdAt: new Date("2026-04-22T09:00:00.000Z"),
        updatedAt: new Date("2026-04-22T10:00:00.000Z"),
      },
      {
        id: "student-12",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        firstName: "Second",
        lastName: "Student",
        serverRevision: 12,
        createdAt: new Date("2026-04-22T09:00:00.000Z"),
        updatedAt: new Date("2026-04-22T10:00:00.000Z"),
      },
      {
        id: "student-13",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        firstName: "Third",
        lastName: "Student",
        serverRevision: 13,
        createdAt: new Date("2026-04-22T09:00:00.000Z"),
        updatedAt: new Date("2026-04-22T10:00:00.000Z"),
      },
    ] as Student[]);

    const result = await service.pull(campusUser, "student", 10, 2);

    expect(students.find).toHaveBeenCalledWith(
      expect.objectContaining({
        take: 3,
      }),
    );
    expect(result.records).toEqual([
      expect.objectContaining({
        revision: 11,
        record: expect.objectContaining({ id: "student-11" }),
      }),
      expect.objectContaining({
        revision: 12,
        record: expect.objectContaining({ id: "student-12" }),
      }),
    ]);
    expect(result).toEqual(
      expect.objectContaining({
        latest_revision: 12,
        next_since: 12,
        has_more: true,
      }),
    );
  });

  it("pulls guardians through campus-scoped student ids without loading full student rows", async () => {
    students.find!.mockResolvedValue([
      { id: "student-1" },
      { id: "student-2" },
    ] as Student[]);
    guardians.find!.mockResolvedValue([
      {
        id: "guardian-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        studentId: "student-1",
        firstName: "Kojo",
        lastName: "Mensah",
        relationship: "father",
        phone: "123",
        serverRevision: 31,
        deleted: false,
        createdAt: new Date("2026-04-22T09:00:00.000Z"),
        updatedAt: new Date("2026-04-22T10:00:00.000Z"),
      },
    ] as Guardian[]);

    const result = await service.pull(campusUser, "guardian", 30, 20);

    expect(students.find).toHaveBeenCalledWith(
      expect.objectContaining({
        select: { id: true },
        where: expect.objectContaining({
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
        }),
        order: { serverRevision: "ASC" },
      }),
    );
    expect(guardians.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: "tenant-1",
          schoolId: "school-1",
          serverRevision: expect.any(Object),
        }),
        order: { serverRevision: "ASC" },
        take: 21,
      }),
    );
    expect(result.records).toEqual([
      expect.objectContaining({
        entity_type: "guardian",
        revision: 31,
        record: expect.objectContaining({
          id: "guardian-1",
          studentId: "student-1",
        }),
      }),
    ]);
  });

  it("pulls staff assignments through campus-scoped staff ids without loading full staff rows", async () => {
    staff.find!.mockResolvedValue([
      { id: "staff-1" },
      { id: "staff-2" },
    ] as Staff[]);
    staffAssignments.find!.mockResolvedValue([
      {
        id: "assignment-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        staffId: "staff-1",
        assignmentType: "subject_teacher",
        subjectId: "subject-1",
        classArmId: null,
        serverRevision: 41,
        deleted: false,
        createdAt: new Date("2026-04-22T09:00:00.000Z"),
        updatedAt: new Date("2026-04-22T10:00:00.000Z"),
      },
    ] as StaffTeachingAssignment[]);

    const result = await service.pull(
      campusUser,
      "staff_teaching_assignment",
      40,
      20,
    );

    expect(staff.find).toHaveBeenCalledWith(
      expect.objectContaining({
        select: { id: true },
        where: expect.objectContaining({
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
        }),
        order: { serverRevision: "ASC" },
      }),
    );
    expect(staffAssignments.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: "tenant-1",
          schoolId: "school-1",
          serverRevision: expect.any(Object),
        }),
        order: { serverRevision: "ASC" },
        take: 21,
      }),
    );
    expect(result.records).toEqual([
      expect.objectContaining({
        entity_type: "staff_teaching_assignment",
        revision: 41,
        record: expect.objectContaining({
          id: "assignment-1",
          staffId: "staff-1",
        }),
      }),
    ]);
  });

  it("uses server revision rather than timestamps when pulling deltas", async () => {
    students.find!.mockResolvedValue([
      {
        id: "student-old",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        firstName: "Old",
        lastName: "Record",
        serverRevision: 10,
        createdAt: new Date("2026-04-22T09:00:00.000Z"),
        updatedAt: new Date("2026-04-22T12:00:00.000Z"),
      },
      {
        id: "student-new",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        firstName: "New",
        lastName: "Record",
        serverRevision: 11,
        createdAt: new Date("2026-04-22T09:00:00.000Z"),
        updatedAt: new Date("2026-04-22T10:00:00.000Z"),
      },
    ] as Student[]);

    const result = await service.pull(campusUser, "student", 10);

    expect(result.latest_revision).toBe(11);
    expect(result.next_since).toBe(11);
    expect(result.has_more).toBe(false);
    expect(result.records).toEqual([
      expect.objectContaining({
        revision: 11,
        record: expect.objectContaining({ id: "student-new" }),
      }),
    ]);
  });

  it("keeps academic pull school-scoped without applying campus filtering", async () => {
    const row = {
      id: "year-1",
      tenantId: "tenant-1",
      schoolId: "school-1",
      label: "2025/2026",
      startDate: "2025-09-01",
      endDate: "2026-07-31",
      isCurrent: true,
      deleted: false,
      createdAt: new Date("2026-04-22T09:00:00.000Z"),
      updatedAt: new Date("2026-04-22T10:00:00.000Z"),
    } as AcademicYear;
    academicYears.find!.mockResolvedValue([row]);

    const result = await service.pull(campusUser, "academic_year", 0);

    expect(academicYears.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: "tenant-1",
          schoolId: "school-1",
          serverRevision: expect.any(Object),
        }),
        order: { serverRevision: "ASC" },
        take: 501,
      }),
    );
    expect(result.records).toHaveLength(1);
  });

  it("pulls grading schemes by school scope using server revisions", async () => {
    gradingSchemes.find!.mockResolvedValue([
      {
        id: "scheme-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        name: "Default",
        bands: [{ grade: "A", min: 80, max: 100, remark: "Excellent" }],
        isDefault: true,
        deleted: false,
        serverRevision: 55,
        createdAt: new Date("2026-04-22T09:00:00.000Z"),
        updatedAt: new Date("2026-04-22T10:00:00.000Z"),
      },
    ] as GradingScheme[]);

    const result = await service.pull(campusUser, "grading_scheme", 0);

    expect(gradingSchemes.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: "tenant-1",
          schoolId: "school-1",
          serverRevision: expect.any(Object),
        }),
        order: { serverRevision: "ASC" },
        take: 501,
      }),
    );
    expect(result.records).toEqual([
      expect.objectContaining({
        entity_type: "grading_scheme",
        revision: 55,
        record: expect.objectContaining({
          id: "scheme-1",
          isDefault: true,
        }),
      }),
    ]);
  });

  it("pulls fee categories by school scope using server revisions", async () => {
    feeCategories.find!.mockResolvedValue([
      {
        id: "fee-category-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        name: "Tuition",
        billingTerm: "per_term",
        isActive: true,
        deleted: false,
        serverRevision: 56,
        createdAt: new Date("2026-04-22T09:00:00.000Z"),
        updatedAt: new Date("2026-04-22T10:00:00.000Z"),
      },
    ] as FeeCategory[]);

    const result = await service.pull(campusUser, "fee_category", 0);

    expect(feeCategories.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: "tenant-1",
          schoolId: "school-1",
          serverRevision: expect.any(Object),
        }),
        order: { serverRevision: "ASC" },
        take: 501,
      }),
    );
    expect(result.records).toEqual([
      expect.objectContaining({
        entity_type: "fee_category",
        revision: 56,
        record: expect.objectContaining({
          id: "fee-category-1",
          name: "Tuition",
        }),
      }),
    ]);
  });

  it("rejects fee structure sync when the referenced fee category belongs to another school", async () => {
    const feeCategoryRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "fee-category-2",
        tenantId: "tenant-1",
        schoolId: "school-2",
      }),
    };
    const feeStructureRepo = {
      findOne: jest.fn().mockResolvedValue(null),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "109" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === FeeStructureItem) {
          return feeStructureRepo;
        }
        if (entity === FeeCategory) {
          return feeCategoryRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-fee-structure-scope-1",
        entity_type: "fee_structure_item",
        entity_id: "fee-structure-1",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          feeCategoryId: "fee-category-2",
          amount: 450,
        },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(auditService.record).not.toHaveBeenCalled();
  });

  it("rejects duplicate fee structure sync for the same category, class, and term rule", async () => {
    const feeCategoryRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "fee-category-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
      }),
    };
    const classLevelRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "class-level-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
      }),
    };
    const termRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "term-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
      }),
    };
    const feeStructureRepo = {
      findOne: jest.fn().mockResolvedValueOnce(null).mockResolvedValueOnce({
        id: "fee-structure-existing",
        tenantId: "tenant-1",
        schoolId: "school-1",
        feeCategoryId: "fee-category-1",
        classLevelId: "class-level-1",
        termId: "term-1",
        deleted: false,
      }),
      save: jest.fn(),
      create: jest.fn((value: unknown) => value),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({
        id: "receipt-1",
      }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "109" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === FeeStructureItem) {
          return feeStructureRepo;
        }
        if (entity === FeeCategory) {
          return feeCategoryRepo;
        }
        if (entity === ClassLevel) {
          return classLevelRepo;
        }
        if (entity === Term) {
          return termRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-fee-structure-duplicate-1",
        entity_type: "fee_structure_item",
        entity_id: "fee-structure-2",
        operation: "create",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          feeCategoryId: "fee-category-1",
          classLevelId: "class-level-1",
          termId: "term-1",
          amount: 500,
        },
      }),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(feeStructureRepo.save).not.toHaveBeenCalled();
    expect(auditService.record).not.toHaveBeenCalled();
  });

  it("pulls campus-scoped invoices by server revision", async () => {
    invoices.find!.mockResolvedValue([
      {
        id: "invoice-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        studentId: "student-1",
        academicYearId: "year-1",
        termId: "term-1",
        classArmId: "arm-1",
        invoiceCode: "INV-1",
        status: "draft",
        lineItems: [{ description: "Tuition", amount: 450 }],
        totalAmount: "450.00",
        generatedByUserId: "user-1",
        postedAt: null,
        syncStatus: "synced",
        deleted: false,
        serverRevision: 57,
        createdAt: new Date("2026-04-22T09:00:00.000Z"),
        updatedAt: new Date("2026-04-22T10:00:00.000Z"),
      },
    ] as Invoice[]);

    const result = await service.pull(campusUser, "invoice", 0);

    expect(invoices.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
          serverRevision: expect.any(Object),
        }),
        order: { serverRevision: "ASC" },
        take: 501,
      }),
    );
    expect(result.records).toEqual([
      expect.objectContaining({
        entity_type: "invoice",
        revision: 57,
        record: expect.objectContaining({
          id: "invoice-1",
          invoiceCode: "INV-1",
        }),
      }),
    ]);
  });

  it("rejects updates to posted payments", async () => {
    const invoiceRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "invoice-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        studentId: "student-1",
        status: "posted",
        deleted: false,
      }),
    };
    const studentRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "student-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
      }),
    };
    const paymentRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: "payment-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        invoiceId: "invoice-1",
        paymentCode: "PAY-1",
        status: "posted",
        amount: "300.00",
        paymentMode: "cash",
        paymentDate: "2026-09-03",
        postedAt: new Date("2026-09-03T10:00:00.000Z"),
        deleted: false,
        serverRevision: 33,
        updatedAt: new Date("2026-09-03T10:00:00.000Z"),
      }),
      save: jest.fn(),
      create: jest.fn((value: unknown) => value),
    };
    const manager = {
      create: jest.fn((_: unknown, value: unknown) => value),
      save: jest.fn().mockResolvedValue({ id: "receipt-1" }),
      update: jest.fn(),
      query: jest.fn().mockResolvedValue([{ revision: "109" }]),
      getRepository: jest.fn((entity: unknown) => {
        if (entity === Payment) {
          return paymentRepo;
        }
        if (entity === Invoice) {
          return invoiceRepo;
        }
        if (entity === Student) {
          return studentRepo;
        }
        return {};
      }),
    };
    dataSource.transaction.mockImplementation(async (callback) =>
      callback(manager),
    );

    await expect(
      service.push(campusUser, {
        idempotency_key: "idem-payment-update-posted-1",
        entity_type: "payment",
        entity_id: "payment-1",
        operation: "update",
        payload: {
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
          invoiceId: "invoice-1",
          paymentCode: "PAY-1",
          status: "posted",
          amount: 300,
          paymentMode: "cash",
          paymentDate: "2026-09-03",
          baseServerRevision: 33,
          baseUpdatedAt: "2026-09-03T10:00:00.000Z",
        },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(paymentRepo.save).not.toHaveBeenCalled();
  });

  it("pulls campus-scoped payments by server revision", async () => {
    payments.find!.mockResolvedValue([
      {
        id: "payment-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        campusId: "campus-1",
        invoiceId: "invoice-1",
        paymentCode: "PAY-1",
        status: "posted",
        amount: "300.00",
        paymentMode: "cash",
        paymentDate: "2026-09-03",
        reference: null,
        notes: null,
        receivedByUserId: "user-1",
        postedAt: new Date("2026-09-03T10:00:00.000Z"),
        syncStatus: "synced",
        deleted: false,
        serverRevision: 58,
        createdAt: new Date("2026-09-03T10:00:00.000Z"),
        updatedAt: new Date("2026-09-03T10:00:00.000Z"),
      },
    ] as Payment[]);

    const result = await service.pull(campusUser, "payment", 0);

    expect(payments.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: "tenant-1",
          schoolId: "school-1",
          campusId: "campus-1",
          serverRevision: expect.any(Object),
        }),
        order: { serverRevision: "ASC" },
        take: 501,
      }),
    );
    expect(result.records).toEqual([
      expect.objectContaining({
        entity_type: "payment",
        revision: 58,
        record: expect.objectContaining({
          id: "payment-1",
          paymentCode: "PAY-1",
        }),
      }),
    ]);
  });

  it("pulls the active school profile by tenant scope using server revisions", async () => {
    schools.find!.mockResolvedValue([
      {
        id: "school-1",
        tenantId: "tenant-1",
        name: "Pilot School",
        shortName: "PS",
        schoolType: "basic",
        address: "Main Street",
        region: "Greater Accra",
        district: "Accra Metro",
        contactPhone: "0200000000",
        contactEmail: "pilot@example.com",
        onboardingDefaults: {},
        deleted: false,
        serverRevision: 60,
        createdAt: new Date("2026-04-22T09:00:00.000Z"),
        updatedAt: new Date("2026-04-22T10:00:00.000Z"),
      },
    ] as School[]);

    const result = await service.pull(campusUser, "school", 0);

    expect(schools.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: "tenant-1",
          id: "school-1",
          serverRevision: expect.any(Object),
        }),
      }),
    );
    expect(result.records).toEqual([
      expect.objectContaining({
        entity_type: "school",
        revision: 60,
        record: expect.objectContaining({
          id: "school-1",
          name: "Pilot School",
        }),
      }),
    ]);
  });

  it("pulls the active campus profile by school scope using server revisions", async () => {
    campuses.find!.mockResolvedValue([
      {
        id: "campus-1",
        tenantId: "tenant-1",
        schoolId: "school-1",
        name: "Main Campus",
        address: "Main Street",
        contactPhone: "0200000000",
        registrationCode: "MAIN",
        deleted: false,
        serverRevision: 61,
        createdAt: new Date("2026-04-22T09:00:00.000Z"),
        updatedAt: new Date("2026-04-22T10:00:00.000Z"),
      },
    ] as Campus[]);

    const result = await service.pull(campusUser, "campus", 0);

    expect(campuses.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: "tenant-1",
          schoolId: "school-1",
          id: "campus-1",
          serverRevision: expect.any(Object),
        }),
      }),
    );
    expect(result.records).toEqual([
      expect.objectContaining({
        entity_type: "campus",
        revision: 61,
        record: expect.objectContaining({
          id: "campus-1",
          name: "Main Campus",
        }),
      }),
    ]);
  });
});
