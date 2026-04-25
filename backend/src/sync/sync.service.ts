import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { createHash } from "crypto";
import { InjectRepository } from "@nestjs/typeorm";
import {
  DataSource,
  EntityManager,
  FindOptionsWhere,
  In,
  IsNull,
  MoreThan,
  Not,
  QueryFailedError,
  Repository,
} from "typeorm";
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
  FeeBillingTerm,
  FeeCategory,
  FeeStructureItem,
  Invoice,
  InvoiceStatus,
  Payment,
  PaymentMode,
  PaymentReversal,
  PaymentStatus,
} from "../finance/finance.entity";
import { School } from "../schools/school.entity";
import { Staff, StaffTeachingAssignment } from "../staff/staff.entity";
import { Enrollment, Guardian, Student } from "../students/student.entity";
import { User } from "../users/user.entity";
import { SyncPushReceipt } from "./sync-push-receipt.entity";
import { SyncReconciliationRequest } from "./sync-reconciliation-request.entity";
import { SyncEntityType, SyncPushRequestDto } from "./dto/sync.dto";

@Injectable()
export class SyncService {
  private static readonly defaultPullLimit = 500;
  private static readonly maxPullLimit = 1000;

  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(AcademicYear)
    private readonly academicYears: Repository<AcademicYear>,
    @InjectRepository(Term)
    private readonly terms: Repository<Term>,
    @InjectRepository(ClassLevel)
    private readonly classLevels: Repository<ClassLevel>,
    @InjectRepository(ClassArm)
    private readonly classArms: Repository<ClassArm>,
    @InjectRepository(Subject)
    private readonly subjects: Repository<Subject>,
    @InjectRepository(School)
    private readonly schools: Repository<School>,
    @InjectRepository(Campus)
    private readonly campuses: Repository<Campus>,
    @InjectRepository(GradingScheme)
    private readonly gradingSchemes: Repository<GradingScheme>,
    @InjectRepository(Student)
    private readonly students: Repository<Student>,
    @InjectRepository(Guardian)
    private readonly guardians: Repository<Guardian>,
    @InjectRepository(Enrollment)
    private readonly enrollments: Repository<Enrollment>,
    @InjectRepository(FeeCategory)
    private readonly feeCategories: Repository<FeeCategory>,
    @InjectRepository(FeeStructureItem)
    private readonly feeStructureItems: Repository<FeeStructureItem>,
    @InjectRepository(Invoice)
    private readonly invoices: Repository<Invoice>,
    @InjectRepository(Payment)
    private readonly payments: Repository<Payment>,
    @InjectRepository(PaymentReversal)
    private readonly paymentReversals: Repository<PaymentReversal>,
    @InjectRepository(Staff)
    private readonly staff: Repository<Staff>,
    @InjectRepository(StaffTeachingAssignment)
    private readonly staffAssignments: Repository<StaffTeachingAssignment>,
    @InjectRepository(Applicant)
    private readonly applicants: Repository<Applicant>,
    @InjectRepository(AttendanceRecord)
    private readonly attendance: Repository<AttendanceRecord>,
    @InjectRepository(SyncPushReceipt)
    private readonly receipts: Repository<SyncPushReceipt>,
    @InjectRepository(SyncReconciliationRequest)
    private readonly reconciliationRequests: Repository<SyncReconciliationRequest>,
    private readonly auditService: AuditService,
  ) {}

  async createReconciliationRequest(
    user: User,
    dto: {
      target_device_id: string;
      campus_id?: string;
      reason?: string;
    },
  ) {
    this.assertRoleAllowedForSyncOperation(
      user,
      "create_reconciliation_request",
    );
    if (!user.tenantId || !user.schoolId) {
      throw new BadRequestException(
        "Authenticated user is missing tenant or school scope.",
      );
    }

    const campusId = this.normalizeRequestedCampusScope(user, dto.campus_id);
    const reason = dto.reason?.trim() || "manual_support_reconcile";

    try {
      const request = await this.reconciliationRequests.save(
        this.reconciliationRequests.create({
          tenantId: user.tenantId,
          schoolId: user.schoolId,
          campusId,
          requestedByUserId: user.id,
          targetDeviceId: dto.target_device_id,
          reason,
          status: "pending",
          requestedAt: new Date(),
          acknowledgedAt: null,
          acknowledgedByUserId: null,
        }),
      );
      await this.auditService.record({
        tenantId: user.tenantId,
        schoolId: user.schoolId,
        campusId,
        actorUserId: user.id,
        eventType: "sync.reconciliation_requested",
        entityType: "sync_reconciliation_request",
        entityId: request.id,
        metadata: {
          targetDeviceId: request.targetDeviceId,
          reason: request.reason,
          status: request.status,
        },
      });
      return this.toReconciliationSummary(request);
    } catch (error) {
      if (this.isPendingReconciliationUniqueViolation(error)) {
        const existing = await this.reconciliationRequests.findOne({
          where: {
            tenantId: user.tenantId,
            schoolId: user.schoolId,
            targetDeviceId: dto.target_device_id,
            status: "pending",
          },
          order: {
            requestedAt: "DESC",
          },
        });
        if (existing) {
          return this.toReconciliationSummary(existing);
        }
      }
      throw error;
    }
  }

  async getPendingReconciliationRequest(user: User, deviceId: string) {
    this.assertRoleAllowedForSyncOperation(user, "view_reconciliation_request");
    if (!user.tenantId || !user.schoolId) {
      throw new BadRequestException(
        "Authenticated user is missing tenant or school scope.",
      );
    }

    const request = await this.reconciliationRequests.findOne({
      where: this.pendingReconciliationScopeWhere(user, deviceId),
      order: {
        requestedAt: "DESC",
      },
    });

    if (!request) {
      return { request: null };
    }

    return { request: this.toReconciliationSummary(request) };
  }

  async acknowledgeReconciliationRequest(
    user: User,
    requestId: string,
    deviceId: string,
  ) {
    this.assertRoleAllowedForSyncOperation(user, "acknowledge_reconciliation");
    if (!user.tenantId || !user.schoolId) {
      throw new BadRequestException(
        "Authenticated user is missing tenant or school scope.",
      );
    }

    const request = await this.reconciliationRequests.findOne({
      where: {
        ...this.pendingReconciliationScopeWhere(user, deviceId),
        id: requestId,
      },
    });
    if (!request) {
      throw new NotFoundException(
        "No pending reconciliation request matched the current device scope.",
      );
    }

    await this.reconciliationRequests.update(request.id, {
      status: "applied",
      acknowledgedAt: new Date(),
      acknowledgedByUserId: user.id,
    });

    await this.auditService.record({
      tenantId: user.tenantId,
      schoolId: user.schoolId,
      campusId: request.campusId,
      actorUserId: user.id,
      eventType: "sync.reconciliation_acknowledged",
      entityType: "sync_reconciliation_request",
      entityId: request.id,
      metadata: {
        targetDeviceId: request.targetDeviceId,
        requestedByUserId: request.requestedByUserId,
        requestedAt: request.requestedAt.toISOString(),
        acknowledgedDeviceId: deviceId,
      },
    });

    return { acknowledged: true, requestId: request.id };
  }

  async push(user: User, dto: SyncPushRequestDto) {
    this.assertRoleAllowedForSyncOperation(user, "push", dto.entity_type);
    this.assertScope(user, dto.entity_type, dto.payload);
    if (!user.tenantId || !user.schoolId) {
      throw new BadRequestException(
        "Authenticated user is missing tenant or school scope.",
      );
    }

    const requestPayloadHash = this.hashSyncRequest(dto);

    try {
      return await this.dataSource.transaction(async (manager) => {
        const receipt = await manager.save(
          SyncPushReceipt,
          manager.create(SyncPushReceipt, {
            idempotencyKey: dto.idempotency_key,
            userId: user.id,
            tenantId: user.tenantId!,
            schoolId: user.schoolId!,
            campusId: user.campusId ?? null,
            originDeviceId: dto.origin_device_id ?? null,
            lamportClock: dto.lamport_clock ?? 0,
            entityType: dto.entity_type,
            entityId: dto.entity_id,
            operation: dto.operation,
            requestPayloadHash,
            responsePayload: {},
          }),
        );

        await this.assertMutationTargetScope(manager, user, dto);
        await this.assertReferencedRecordScope(manager, user, dto);
        const canonicalEntityId = await this.applyPushMutation(
          manager,
          user,
          dto,
        );
        const serverRevision = await this.loadEntityServerRevision(
          manager,
          user,
          dto.entity_type,
          canonicalEntityId,
        );
        const requestedEntityId =
          canonicalEntityId === dto.entity_id ? undefined : dto.entity_id;
        await this.auditService.record(
          {
            tenantId: user.tenantId!,
            schoolId: user.schoolId!,
            campusId:
              user.campusId ??
              ((dto.payload["campusId"] as string | undefined) || null),
            actorUserId: user.id,
            eventType: `sync.${dto.entity_type}.${dto.operation}`,
            entityType: dto.entity_type,
            entityId: canonicalEntityId,
            metadata: {
              idempotencyKey: dto.idempotency_key,
              originDeviceId: dto.origin_device_id ?? null,
              lamportClock: dto.lamport_clock ?? 0,
              operation: dto.operation,
              receiptId: receipt.id,
              requestedEntityId: requestedEntityId ?? null,
              serverRevision,
            },
          },
          manager,
        );

        const response = {
          status: "accepted",
          entityType: dto.entity_type,
          entityId: canonicalEntityId,
          requestedEntityId,
          serverRevision,
          operation: dto.operation,
        };

        await manager.update(SyncPushReceipt, receipt.id, {
          canonicalEntityId,
          serverRevision,
          responsePayload: response,
          completedAt: new Date(),
        });

        return response;
      });
    } catch (error) {
      if (!this.isIdempotencyUniqueViolation(error)) {
        throw error;
      }

      const existing = await this.receipts.findOne({
        where: {
          idempotencyKey: dto.idempotency_key,
          tenantId: user.tenantId,
          schoolId: user.schoolId,
          userId: user.id,
        },
      });
      this.assertIdempotentReplayMatches(existing, dto, requestPayloadHash);
      return this.completedReplayResponse(existing);
    }
  }

  private completedReplayResponse(existing: SyncPushReceipt | null) {
    if (!existing?.completedAt) {
      throw new ConflictException(
        "Idempotency key is already in use by an incomplete sync push.",
      );
    }

    if (
      existing.responsePayload &&
      Object.keys(existing.responsePayload).length > 0
    ) {
      return existing.responsePayload;
    }

    if (existing.canonicalEntityId && existing.serverRevision !== null) {
      return {
        status: "accepted",
        entityType: existing.entityType,
        entityId: existing.canonicalEntityId,
        serverRevision: Number(existing.serverRevision),
        operation: existing.operation,
      };
    }

    throw new ConflictException(
      "Idempotency key is already in use by an incomplete sync push.",
    );
  }

  private assertIdempotentReplayMatches(
    existing: SyncPushReceipt | null,
    dto: SyncPushRequestDto,
    requestPayloadHash: string,
  ) {
    if (!existing) {
      throw new ConflictException(
        "Idempotency key is already in use outside the authenticated sync scope.",
      );
    }

    const sameRequest =
      existing.entityType === dto.entity_type &&
      existing.entityId === dto.entity_id &&
      existing.operation === dto.operation &&
      (!existing.requestPayloadHash ||
        existing.requestPayloadHash === requestPayloadHash);

    if (!sameRequest) {
      throw new ConflictException(
        "Idempotency key replay does not match the original sync request.",
      );
    }
  }

  async pull(
    user: User,
    entityType: SyncEntityType,
    since: number,
    limit?: number,
  ) {
    this.assertRoleAllowedForSyncOperation(user, "pull", entityType);
    this.assertValidPullCursor(entityType, since);
    const pullLimit = this.normalizePullLimit(entityType, limit);
    const rows = await this.rowsForPull(user, entityType, since, pullLimit + 1);
    const pageRows = rows.slice(0, pullLimit);

    const records = pageRows
      .filter((row) => this.revisionFor(row) > since)
      .map((row) => this.toSyncRecord(entityType, row));

    const latestRevision = pageRows.reduce(
      (max, row) => Math.max(max, this.revisionFor(row)),
      since,
    );

    return {
      records,
      latest_revision: latestRevision,
      has_more: rows.length > pullLimit,
      next_since: latestRevision,
    };
  }

  private assertValidPullCursor(entityType: SyncEntityType, since: number) {
    if (!Number.isInteger(since) || since < 0) {
      throw new BadRequestException(
        `Sync pull cursor has an invalid revision for '${entityType}'.`,
      );
    }
  }

  private normalizePullLimit(entityType: SyncEntityType, limit?: number) {
    if (limit === undefined || limit === null) {
      return SyncService.defaultPullLimit;
    }

    if (!Number.isInteger(limit) || limit < 1) {
      throw new BadRequestException(
        `Sync pull limit has an invalid value for '${entityType}'.`,
      );
    }

    return Math.min(limit, SyncService.maxPullLimit);
  }

  private assertScope(
    user: User,
    entityType: SyncEntityType,
    payload: Record<string, unknown>,
  ) {
    if (!user.tenantId || !user.schoolId) {
      throw new BadRequestException(
        "Authenticated user is missing tenant or school scope.",
      );
    }

    const schoolScopedEntity = entityType !== "school";
    if (
      payload["tenantId"] !== user.tenantId ||
      (schoolScopedEntity && payload["schoolId"] !== user.schoolId)
    ) {
      throw new BadRequestException(
        "Sync payload scope does not match the authenticated user.",
      );
    }

    if (
      user.campusId &&
      this.isDirectCampusScopedEntity(entityType) &&
      payload["campusId"] !== user.campusId
    ) {
      throw new BadRequestException(
        "Sync payload campus does not match the authenticated device scope.",
      );
    }
  }

  private async applyPushMutation(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    switch (dto.entity_type) {
      case "student":
        return this.upsertStudent(manager, user, dto);
      case "guardian":
        return this.upsertGuardian(manager, user, dto);
      case "enrollment":
        return this.upsertEnrollment(manager, user, dto);
      case "fee_category":
        return this.upsertFeeCategory(manager, user, dto);
      case "fee_structure_item":
        return this.upsertFeeStructureItem(manager, user, dto);
      case "invoice":
        return this.upsertInvoice(manager, user, dto);
      case "payment":
        return this.upsertPayment(manager, user, dto);
      case "payment_reversal":
        return this.upsertPaymentReversal(manager, user, dto);
      case "staff":
        return this.upsertStaff(manager, user, dto);
      case "staff_teaching_assignment":
        return this.upsertStaffTeachingAssignment(manager, user, dto);
      case "applicant":
        return this.upsertApplicant(manager, user, dto);
      case "attendance_record":
        return this.upsertAttendance(manager, user, dto);
      case "academic_year":
        return this.upsertAcademicYear(manager, user, dto);
      case "term":
        return this.upsertTerm(manager, user, dto);
      case "class_level":
        return this.upsertClassLevel(manager, user, dto);
      case "class_arm":
        return this.upsertClassArm(manager, user, dto);
      case "subject":
        return this.upsertSubject(manager, user, dto);
      case "school":
        return this.upsertSchool(manager, user, dto);
      case "campus":
        return this.upsertCampus(manager, user, dto);
      case "grading_scheme":
        return this.upsertGradingScheme(manager, user, dto);
      default:
        throw new BadRequestException(
          `Unsupported entity type '${dto.entity_type}'.`,
        );
    }
  }

  private async assertReferencedRecordScope(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    switch (dto.entity_type) {
      case "student":
      case "staff":
        await this.assertCampusReferenceInScope(
          manager,
          user,
          dto.payload["campusId"] as string | undefined,
          dto.entity_type,
        );
        break;
      case "guardian":
        await this.assertStudentReferenceInScope(
          manager,
          user,
          (dto.payload["studentId"] as string | undefined) ??
            (await this.existingGuardianStudentId(
              manager,
              user,
              dto.entity_id,
            )),
          dto.entity_type,
        );
        break;
      case "enrollment":
        await this.assertStudentReferenceInScope(
          manager,
          user,
          (dto.payload["studentId"] as string | undefined) ??
            (await this.existingEnrollmentStudentId(
              manager,
              user,
              dto.entity_id,
            )),
          dto.entity_type,
        );
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          ClassArm,
          dto.payload["classArmId"] as string | undefined,
          dto.entity_type,
          "class arm",
        );
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          AcademicYear,
          dto.payload["academicYearId"] as string | undefined,
          dto.entity_type,
          "academic year",
        );
        break;
      case "fee_structure_item":
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          FeeCategory,
          (dto.payload["feeCategoryId"] as string | undefined) ??
            (await this.existingFeeStructureCategoryId(
              manager,
              user,
              dto.entity_id,
            )),
          dto.entity_type,
          "fee category",
        );
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          ClassLevel,
          dto.payload["classLevelId"] as string | undefined,
          dto.entity_type,
          "class level",
        );
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          Term,
          dto.payload["termId"] as string | undefined,
          dto.entity_type,
          "term",
        );
        break;
      case "invoice":
        await this.assertCampusReferenceInScope(
          manager,
          user,
          dto.payload["campusId"] as string | undefined,
          dto.entity_type,
        );
        await this.assertStudentReferenceInScope(
          manager,
          user,
          (dto.payload["studentId"] as string | undefined) ??
            (await this.existingInvoiceStudentId(manager, user, dto.entity_id)),
          dto.entity_type,
        );
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          AcademicYear,
          dto.payload["academicYearId"] as string | undefined,
          dto.entity_type,
          "academic year",
        );
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          Term,
          dto.payload["termId"] as string | undefined,
          dto.entity_type,
          "term",
        );
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          ClassArm,
          dto.payload["classArmId"] as string | undefined,
          dto.entity_type,
          "class arm",
        );
        break;
      case "payment":
        await this.assertCampusReferenceInScope(
          manager,
          user,
          dto.payload["campusId"] as string | undefined,
          dto.entity_type,
        );
        await this.assertStudentReferenceInScope(
          manager,
          user,
          await this.existingInvoiceStudentId(
            manager,
            user,
            (dto.payload["invoiceId"] as string | undefined) ??
              (await this.existingPaymentInvoiceId(
                manager,
                user,
                dto.entity_id,
              )),
          ),
          dto.entity_type,
        );
        break;
      case "payment_reversal":
        await this.assertCampusReferenceInScope(
          manager,
          user,
          dto.payload["campusId"] as string | undefined,
          dto.entity_type,
        );
        await this.assertStudentReferenceInScope(
          manager,
          user,
          await this.existingInvoiceStudentId(
            manager,
            user,
            (dto.payload["invoiceId"] as string | undefined) ??
              (await this.existingPaymentReversalInvoiceId(
                manager,
                user,
                dto.entity_id,
              )),
          ),
          dto.entity_type,
        );
        break;
      case "attendance_record":
        await this.assertCampusReferenceInScope(
          manager,
          user,
          dto.payload["campusId"] as string | undefined,
          dto.entity_type,
        );
        await this.assertStudentReferenceInScope(
          manager,
          user,
          (dto.payload["studentId"] as string | undefined) ??
            (await this.existingAttendanceStudentId(
              manager,
              user,
              dto.entity_id,
            )),
          dto.entity_type,
        );
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          ClassArm,
          dto.payload["classArmId"] as string | undefined,
          dto.entity_type,
          "class arm",
        );
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          AcademicYear,
          dto.payload["academicYearId"] as string | undefined,
          dto.entity_type,
          "academic year",
        );
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          Term,
          dto.payload["termId"] as string | undefined,
          dto.entity_type,
          "term",
        );
        break;
      case "staff_teaching_assignment":
        await this.assertStaffReferenceInScope(
          manager,
          user,
          (dto.payload["staffId"] as string | undefined) ??
            (await this.existingStaffAssignmentStaffId(
              manager,
              user,
              dto.entity_id,
            )),
          dto.entity_type,
        );
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          Subject,
          dto.payload["subjectId"] as string | undefined,
          dto.entity_type,
          "subject",
        );
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          ClassArm,
          dto.payload["classArmId"] as string | undefined,
          dto.entity_type,
          "class arm",
        );
        break;
      case "applicant":
        await this.assertCampusReferenceInScope(
          manager,
          user,
          dto.payload["campusId"] as string | undefined,
          dto.entity_type,
        );
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          ClassLevel,
          dto.payload["classLevelId"] as string | undefined,
          dto.entity_type,
          "class level",
        );
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          AcademicYear,
          dto.payload["academicYearId"] as string | undefined,
          dto.entity_type,
          "academic year",
        );
        await this.assertStudentReferenceInScope(
          manager,
          user,
          dto.payload["studentId"] as string | undefined,
          dto.entity_type,
        );
        break;
      case "term":
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          AcademicYear,
          dto.payload["academicYearId"] as string | undefined,
          dto.entity_type,
          "academic year",
        );
        break;
      case "class_arm":
        await this.assertSchoolReferenceInScope(
          manager,
          user,
          ClassLevel,
          dto.payload["classLevelId"] as string | undefined,
          dto.entity_type,
          "class level",
        );
        break;
    }
  }

  private async assertMutationTargetScope(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const repository = this.repositoryForSyncEntity(manager, dto.entity_type);
    if (!repository) {
      return;
    }

    const existing = (await repository.findOne({
      where: this.syncEntityScopeWhere(user, dto.entity_type, dto.entity_id),
    })) as {
      tenantId?: string | null;
      schoolId?: string | null;
      campusId?: string | null;
    } | null;

    if (!existing) {
      if (dto.operation !== "create") {
        throw new BadRequestException(
          `Sync ${dto.operation} target '${dto.entity_type}/${dto.entity_id}' does not exist in the authenticated scope.`,
        );
      }
      return;
    }

    if (dto.operation === "create") {
      throw new ConflictException({
        code: "sync_conflict",
        conflictType: "duplicate_create",
        entityType: dto.entity_type,
        entityId: dto.entity_id,
        message: `Sync create target '${dto.entity_type}/${dto.entity_id}' already exists in the authenticated scope.`,
        serverRecord: existing,
      });
    }

    const campusMismatch =
      user.campusId &&
      this.isDirectCampusScopedEntity(dto.entity_type) &&
      existing.campusId !== user.campusId;

    if (
      existing.tenantId !== user.tenantId ||
      (dto.entity_type !== "school" && existing.schoolId !== user.schoolId) ||
      campusMismatch
    ) {
      throw new BadRequestException(
        `Sync ${dto.operation} target '${dto.entity_type}/${dto.entity_id}' is outside the authenticated scope.`,
      );
    }
  }

  private repositoryForSyncEntity(
    manager: EntityManager,
    entityType: SyncEntityType,
  ): Repository<object> | null {
    switch (entityType) {
      case "student":
        return manager.getRepository(Student) as Repository<object>;
      case "guardian":
        return manager.getRepository(Guardian) as Repository<object>;
      case "enrollment":
        return manager.getRepository(Enrollment) as Repository<object>;
      case "fee_category":
        return manager.getRepository(FeeCategory) as Repository<object>;
      case "fee_structure_item":
        return manager.getRepository(FeeStructureItem) as Repository<object>;
      case "invoice":
        return manager.getRepository(Invoice) as Repository<object>;
      case "payment":
        return manager.getRepository(Payment) as Repository<object>;
      case "payment_reversal":
        return manager.getRepository(PaymentReversal) as Repository<object>;
      case "staff":
        return manager.getRepository(Staff) as Repository<object>;
      case "staff_teaching_assignment":
        return manager.getRepository(
          StaffTeachingAssignment,
        ) as Repository<object>;
      case "school":
        return manager.getRepository(School) as Repository<object>;
      case "campus":
        return manager.getRepository(Campus) as Repository<object>;
      case "grading_scheme":
        return manager.getRepository(GradingScheme) as Repository<object>;
      case "applicant":
        return manager.getRepository(Applicant) as Repository<object>;
      case "attendance_record":
        return manager.getRepository(AttendanceRecord) as Repository<object>;
      case "academic_year":
        return manager.getRepository(AcademicYear) as Repository<object>;
      case "term":
        return manager.getRepository(Term) as Repository<object>;
      case "class_level":
        return manager.getRepository(ClassLevel) as Repository<object>;
      case "class_arm":
        return manager.getRepository(ClassArm) as Repository<object>;
      case "subject":
        return manager.getRepository(Subject) as Repository<object>;
      default:
        return null;
    }
  }

  private syncEntityScopeWhere(
    user: User,
    entityType: SyncEntityType,
    entityId: string,
  ) {
    const where: Record<string, unknown> = {
      id: entityId,
      tenantId: user.tenantId,
    };

    if (entityType !== "school") {
      where["schoolId"] = user.schoolId;
    }

    if (user.campusId && this.isDirectCampusScopedEntity(entityType)) {
      where["campusId"] = user.campusId;
    }

    return where as never;
  }

  private async loadEntityServerRevision(
    manager: EntityManager,
    user: User,
    entityType: SyncEntityType,
    entityId: string,
  ) {
    const repository = this.repositoryForSyncEntity(manager, entityType);
    if (!repository) {
      throw new BadRequestException(
        `Unsupported entity type '${entityType}' for sync acknowledgement.`,
      );
    }

    const row = (await repository.findOne({
      where: this.syncEntityScopeWhere(user, entityType, entityId),
    })) as { updatedAt: Date; serverRevision?: number | string } | null;

    if (!row) {
      throw new BadRequestException(
        `Sync mutation target '${entityType}/${entityId}' was not found after mutation.`,
      );
    }

    return this.revisionFor(row);
  }

  private async upsertStudent(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const students = manager.getRepository(Student);
    if (dto.operation === "delete") {
      await this.assertNotStale(
        students,
        user,
        dto.entity_id,
        dto.payload,
        "student",
      );
      await students.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
          syncStatus: "synced",
        },
      );
      return dto.entity_id;
    }

    const payload = dto.payload;
    if (dto.operation !== "create") {
      await this.assertNotStale(
        students,
        user,
        dto.entity_id,
        payload,
        "student",
      );
    }
    await students.save(
      students.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        campusId: (payload["campusId"] as string | undefined) ?? null,
        studentNumber: (payload["studentNumber"] as string | undefined) ?? null,
        firstName: payload["firstName"] as string,
        middleName: (payload["middleName"] as string | undefined) ?? null,
        lastName: payload["lastName"] as string,
        dateOfBirth: (payload["dateOfBirth"] as string | undefined) ?? null,
        gender: (payload["gender"] as Student["gender"]) ?? null,
        status: payload["status"] as Student["status"],
        serverRevision: await this.nextServerRevision(manager),
        syncStatus: "synced",
        deleted: false,
      }),
    );
    return dto.entity_id;
  }

  private async upsertStaff(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const staff = manager.getRepository(Staff);
    if (dto.operation === "delete") {
      await this.assertNotStale(
        staff,
        user,
        dto.entity_id,
        dto.payload,
        "staff",
      );
      await staff.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
          syncStatus: "synced",
        },
      );
      return dto.entity_id;
    }

    const payload = dto.payload;
    if (dto.operation !== "create") {
      await this.assertNotStale(staff, user, dto.entity_id, payload, "staff");
    }
    await staff.save(
      staff.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        campusId: (payload["campusId"] as string | undefined) ?? null,
        staffNumber: (payload["staffNumber"] as string | undefined) ?? null,
        firstName: payload["firstName"] as string,
        middleName: (payload["middleName"] as string | undefined) ?? null,
        lastName: payload["lastName"] as string,
        gender: (payload["gender"] as Staff["gender"]) ?? null,
        phone: (payload["phone"] as string | undefined) ?? null,
        email: (payload["email"] as string | undefined) ?? null,
        department: (payload["department"] as string | undefined) ?? null,
        systemRole: payload["systemRole"] as Staff["systemRole"],
        employmentType: payload["employmentType"] as Staff["employmentType"],
        dateJoined: (payload["dateJoined"] as string | undefined) ?? null,
        isActive: (payload["isActive"] as boolean | undefined) ?? true,
        serverRevision: await this.nextServerRevision(manager),
        syncStatus: "synced",
        deleted: false,
      }),
    );
    return dto.entity_id;
  }

  private async upsertGuardian(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const guardians = manager.getRepository(Guardian);
    if (dto.operation === "delete") {
      await this.assertNotStale(
        guardians,
        user,
        dto.entity_id,
        dto.payload,
        "guardian",
      );
      await guardians.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
        },
      );
      return dto.entity_id;
    }

    const payload = dto.payload;
    if (dto.operation !== "create") {
      await this.assertNotStale(
        guardians,
        user,
        dto.entity_id,
        payload,
        "guardian",
      );
    }
    await guardians.save(
      guardians.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        studentId: payload["studentId"] as string,
        firstName: payload["firstName"] as string,
        lastName: payload["lastName"] as string,
        relationship: payload["relationship"] as Guardian["relationship"],
        phone: (payload["phone"] as string | undefined) ?? null,
        email: (payload["email"] as string | undefined) ?? null,
        isPrimary: (payload["isPrimary"] as boolean | undefined) ?? false,
        serverRevision: await this.nextServerRevision(manager),
        deleted: false,
      }),
    );
    return dto.entity_id;
  }

  private async upsertStaffTeachingAssignment(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const staffAssignments = manager.getRepository(StaffTeachingAssignment);
    if (dto.operation === "delete") {
      await this.assertNotStale(
        staffAssignments,
        user,
        dto.entity_id,
        dto.payload,
        "staff_teaching_assignment",
      );
      await staffAssignments.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
        },
      );
      return dto.entity_id;
    }

    const payload = dto.payload;
    if (dto.operation !== "create") {
      await this.assertNotStale(
        staffAssignments,
        user,
        dto.entity_id,
        payload,
        "staff_teaching_assignment",
      );
    }
    await staffAssignments.save(
      staffAssignments.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        staffId: payload["staffId"] as string,
        assignmentType: payload[
          "assignmentType"
        ] as StaffTeachingAssignment["assignmentType"],
        subjectId: (payload["subjectId"] as string | undefined) ?? null,
        classArmId: (payload["classArmId"] as string | undefined) ?? null,
        serverRevision: await this.nextServerRevision(manager),
        deleted: false,
      }),
    );
    return dto.entity_id;
  }

  private async upsertEnrollment(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const enrollments = manager.getRepository(Enrollment);
    const payload = dto.payload;
    const existing =
      (await enrollments.findOne({
        where: {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
      })) ??
      (await enrollments.findOne({
        where: {
          tenantId: payload["tenantId"] as string,
          schoolId: payload["schoolId"] as string,
          studentId: payload["studentId"] as string,
          academicYearId: payload["academicYearId"] as string,
          deleted: false,
        },
      }));

    if (dto.operation === "delete") {
      if (existing) {
        await this.assertNotStale(
          enrollments,
          user,
          existing.id,
          dto.payload,
          "enrollment",
        );
        await enrollments.update(
          {
            id: existing.id,
            tenantId: user.tenantId!,
            schoolId: user.schoolId!,
          },
          {
            deleted: true,
            serverRevision: await this.nextServerRevision(manager),
          },
        );
        return existing.id;
      }
      return dto.entity_id;
    }

    if (dto.operation !== "create") {
      await this.assertNotStale(
        enrollments,
        user,
        existing?.id ?? dto.entity_id,
        payload,
        "enrollment",
      );
    }
    const canonicalEntityId = existing?.id ?? dto.entity_id;
    await enrollments.save(
      enrollments.create({
        id: canonicalEntityId,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        studentId: payload["studentId"] as string,
        classArmId: payload["classArmId"] as string,
        academicYearId: payload["academicYearId"] as string,
        enrollmentDate: payload["enrollmentDate"] as string,
        serverRevision: await this.nextServerRevision(manager),
        deleted: false,
      }),
    );
    return canonicalEntityId;
  }

  private async upsertFeeCategory(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const feeCategories = manager.getRepository(FeeCategory);
    if (dto.operation === "delete") {
      await this.assertNotStale(
        feeCategories,
        user,
        dto.entity_id,
        dto.payload,
        "fee_category",
      );
      await feeCategories.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
        },
      );
      return dto.entity_id;
    }

    const payload = dto.payload;
    if (dto.operation !== "create") {
      await this.assertNotStale(
        feeCategories,
        user,
        dto.entity_id,
        payload,
        "fee_category",
      );
    }
    await feeCategories.save(
      feeCategories.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        name: payload["name"] as string,
        billingTerm:
          (payload["billingTerm"] as FeeCategory["billingTerm"] | undefined) ??
          FeeBillingTerm.PerTerm,
        isActive: (payload["isActive"] as boolean | undefined) ?? true,
        serverRevision: await this.nextServerRevision(manager),
        deleted: false,
      }),
    );
    return dto.entity_id;
  }

  private async upsertFeeStructureItem(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const feeStructureItems = manager.getRepository(FeeStructureItem);
    if (dto.operation === "delete") {
      await this.assertNotStale(
        feeStructureItems,
        user,
        dto.entity_id,
        dto.payload,
        "fee_structure_item",
      );
      await feeStructureItems.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
        },
      );
      return dto.entity_id;
    }

    const payload = dto.payload;
    if (dto.operation !== "create") {
      await this.assertNotStale(
        feeStructureItems,
        user,
        dto.entity_id,
        payload,
        "fee_structure_item",
      );
    }
    await this.assertUniqueFeeStructureItemRule(
      manager,
      user,
      dto.entity_id,
      payload,
    );
    await feeStructureItems.save(
      feeStructureItems.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        feeCategoryId: payload["feeCategoryId"] as string,
        classLevelId: (payload["classLevelId"] as string | undefined) ?? null,
        termId: (payload["termId"] as string | undefined) ?? null,
        amount: `${payload["amount"]}`,
        notes: (payload["notes"] as string | undefined) ?? null,
        serverRevision: await this.nextServerRevision(manager),
        deleted: false,
      }),
    );
    return dto.entity_id;
  }

  private async assertUniqueFeeStructureItemRule(
    manager: EntityManager,
    user: User,
    entityId: string,
    payload: Record<string, unknown>,
  ) {
    const classLevelId =
      (payload["classLevelId"] as string | undefined) ?? null;
    const termId = (payload["termId"] as string | undefined) ?? null;
    const conflict = await manager.getRepository(FeeStructureItem).findOne({
      where: {
        id: Not(entityId),
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
        feeCategoryId: payload["feeCategoryId"] as string,
        classLevelId: classLevelId ?? IsNull(),
        termId: termId ?? IsNull(),
        deleted: false,
      },
    });
    if (conflict) {
      throw new ConflictException(
        "A fee structure variation already exists for this category, class, and term combination.",
      );
    }
  }

  private async upsertInvoice(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const invoices = manager.getRepository(Invoice);
    const payload = dto.payload;
    const existing = await invoices.findOne({
      where: {
        id: dto.entity_id,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      },
    });

    if (dto.operation === "delete") {
      if (!existing) {
        return dto.entity_id;
      }
      if (existing.status === InvoiceStatus.Posted) {
        throw new BadRequestException(
          "Posted invoices are immutable and cannot be deleted.",
        );
      }
      await this.assertNotStale(
        invoices,
        user,
        dto.entity_id,
        payload,
        "invoice",
      );
      await invoices.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
          syncStatus: "synced",
        },
      );
      return dto.entity_id;
    }

    const nextStatus =
      (payload["status"] as InvoiceStatus | undefined) ?? InvoiceStatus.Draft;
    if (existing) {
      await this.assertNotStale(
        invoices,
        user,
        dto.entity_id,
        payload,
        "invoice",
      );
      if (existing.status === InvoiceStatus.Posted) {
        throw new BadRequestException(
          "Posted invoices are immutable and cannot be updated.",
        );
      }
      const allowedTransition =
        existing.status === nextStatus ||
        (existing.status === InvoiceStatus.Draft &&
          (nextStatus === InvoiceStatus.Draft ||
            nextStatus === InvoiceStatus.Confirmed)) ||
        (existing.status === InvoiceStatus.Confirmed &&
          (nextStatus === InvoiceStatus.Confirmed ||
            nextStatus === InvoiceStatus.Posted));
      if (!allowedTransition) {
        throw new BadRequestException(
          `Invoice lifecycle transition '${existing.status}' -> '${nextStatus}' is not allowed.`,
        );
      }
    }

    await invoices.save(
      invoices.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        campusId: (payload["campusId"] as string | undefined) ?? null,
        studentId: payload["studentId"] as string,
        academicYearId: payload["academicYearId"] as string,
        termId: payload["termId"] as string,
        classArmId: payload["classArmId"] as string,
        invoiceCode: payload["invoiceCode"] as string,
        status: nextStatus,
        lineItems: (payload["lineItems"] as object[] | undefined) ?? [],
        totalAmount: `${payload["totalAmount"]}`,
        generatedByUserId:
          (payload["generatedByUserId"] as string | undefined) ?? null,
        postedAt: payload["postedAt"]
          ? new Date(payload["postedAt"] as string)
          : null,
        syncStatus: "synced",
        serverRevision: await this.nextServerRevision(manager),
        deleted: false,
      }),
    );
    return dto.entity_id;
  }

  private async upsertPayment(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const payments = manager.getRepository(Payment);
    const payload = dto.payload;
    const existing = await payments.findOne({
      where: {
        id: dto.entity_id,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      },
    });

    if (dto.operation === "delete") {
      if (!existing) {
        return dto.entity_id;
      }
      if (existing.status === PaymentStatus.Posted) {
        throw new BadRequestException(
          "Posted payments are immutable and cannot be deleted.",
        );
      }
      await this.assertNotStale(
        payments,
        user,
        dto.entity_id,
        payload,
        "payment",
      );
      await payments.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          syncStatus: "synced",
          serverRevision: await this.nextServerRevision(manager),
        },
      );
      return dto.entity_id;
    }

    const invoiceId =
      (payload["invoiceId"] as string | undefined) ?? existing?.invoiceId;
    const invoice = await manager.getRepository(Invoice).findOne({
      where: {
        id: invoiceId,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      },
    });
    if (!invoice || invoice.deleted) {
      throw new BadRequestException("Payment invoice was not found in scope.");
    }
    if (invoice.status !== InvoiceStatus.Posted) {
      throw new BadRequestException(
        "Payments can only be recorded against posted invoices.",
      );
    }

    const nextStatus =
      (payload["status"] as PaymentStatus | undefined) ?? PaymentStatus.Draft;
    if (existing) {
      await this.assertNotStale(
        payments,
        user,
        dto.entity_id,
        payload,
        "payment",
      );
      if (existing.status === PaymentStatus.Posted) {
        throw new BadRequestException(
          "Posted payments are immutable and cannot be updated.",
        );
      }
      const allowedTransition =
        existing.status === nextStatus ||
        (existing.status === PaymentStatus.Draft &&
          (nextStatus === PaymentStatus.Draft ||
            nextStatus === PaymentStatus.Confirmed)) ||
        (existing.status === PaymentStatus.Confirmed &&
          (nextStatus === PaymentStatus.Confirmed ||
            nextStatus === PaymentStatus.Posted));
      if (!allowedTransition) {
        throw new BadRequestException(
          `Payment lifecycle transition '${existing.status}' -> '${nextStatus}' is not allowed.`,
        );
      }
      if (nextStatus === PaymentStatus.Posted) {
        await this.assertPaymentDoesNotExceedOutstanding(
          manager,
          user,
          invoice.id,
          Number(payload["amount"] ?? existing.amount),
          existing.id,
        );
      }
    } else if (nextStatus === PaymentStatus.Posted) {
      await this.assertPaymentDoesNotExceedOutstanding(
        manager,
        user,
        invoice.id,
        Number(payload["amount"]),
      );
    }

    await payments.save(
      payments.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        campusId: (payload["campusId"] as string | undefined) ?? null,
        invoiceId: invoice.id,
        paymentCode:
          (payload["paymentCode"] as string | undefined) ??
          existing?.paymentCode,
        status: nextStatus,
        amount: `${payload["amount"] ?? existing?.amount}`,
        paymentMode: ((payload["paymentMode"] as PaymentMode | undefined) ??
          existing?.paymentMode) as PaymentMode,
        paymentDate:
          (payload["paymentDate"] as string | undefined) ??
          existing?.paymentDate,
        reference:
          (payload["reference"] as string | undefined) ??
          existing?.reference ??
          null,
        notes:
          (payload["notes"] as string | undefined) ?? existing?.notes ?? null,
        receivedByUserId:
          (payload["receivedByUserId"] as string | undefined) ??
          existing?.receivedByUserId ??
          null,
        postedAt:
          payload["postedAt"] == null
            ? (existing?.postedAt ?? null)
            : new Date(payload["postedAt"] as string),
        syncStatus: "synced",
        serverRevision: await this.nextServerRevision(manager),
        deleted: false,
      }),
    );
    return dto.entity_id;
  }

  private async upsertPaymentReversal(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const reversals = manager.getRepository(PaymentReversal);
    if (dto.operation !== "create") {
      throw new BadRequestException(
        "Payment reversal entries are immutable and cannot be updated or deleted.",
      );
    }

    const payload = dto.payload;
    const payment = await manager.getRepository(Payment).findOne({
      where: {
        id: payload["paymentId"] as string,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      },
    });
    if (!payment || payment.deleted) {
      throw new BadRequestException(
        "Payment reversal target was not found in scope.",
      );
    }
    if (payment.status !== PaymentStatus.Posted) {
      throw new BadRequestException("Only posted payments can be reversed.");
    }

    const duplicate = await reversals.findOne({
      where: {
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
        paymentId: payment.id,
        deleted: false,
      },
    });
    if (duplicate) {
      throw new ConflictException(
        "A reversal already exists for this payment.",
      );
    }

    await reversals.save(
      reversals.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        campusId: (payload["campusId"] as string | undefined) ?? null,
        paymentId: payment.id,
        invoiceId: payload["invoiceId"] as string,
        amount: `${payload["amount"]}`,
        reason: payload["reason"] as string,
        reversedByUserId:
          (payload["reversedByUserId"] as string | undefined) ?? null,
        syncStatus: "synced",
        serverRevision: await this.nextServerRevision(manager),
        deleted: false,
      }),
    );
    return dto.entity_id;
  }

  private async upsertApplicant(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const applicants = manager.getRepository(Applicant);
    if (dto.operation === "delete") {
      await this.assertNotStale(
        applicants,
        user,
        dto.entity_id,
        dto.payload,
        "applicant",
      );
      await applicants.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
          syncStatus: "synced",
        },
      );
      return dto.entity_id;
    }

    const payload = dto.payload;
    if (dto.operation !== "create") {
      await this.assertNotStale(
        applicants,
        user,
        dto.entity_id,
        payload,
        "applicant",
      );
    }
    await applicants.save(
      applicants.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        campusId: (payload["campusId"] as string | undefined) ?? null,
        firstName: payload["firstName"] as string,
        middleName: (payload["middleName"] as string | undefined) ?? null,
        lastName: payload["lastName"] as string,
        dateOfBirth: (payload["dateOfBirth"] as string | undefined) ?? null,
        gender: (payload["gender"] as Applicant["gender"]) ?? null,
        classLevelId: (payload["classLevelId"] as string | undefined) ?? null,
        academicYearId:
          (payload["academicYearId"] as string | undefined) ?? null,
        guardianName: (payload["guardianName"] as string | undefined) ?? null,
        guardianPhone: (payload["guardianPhone"] as string | undefined) ?? null,
        guardianEmail: (payload["guardianEmail"] as string | undefined) ?? null,
        documentNotes: (payload["documentNotes"] as string | undefined) ?? null,
        status: payload["status"] as Applicant["status"],
        studentId: (payload["studentId"] as string | undefined) ?? null,
        admittedAt: payload["admittedAt"]
          ? new Date(payload["admittedAt"] as string)
          : null,
        serverRevision: await this.nextServerRevision(manager),
        syncStatus: "synced",
        deleted: false,
      }),
    );
    return dto.entity_id;
  }

  private async upsertAttendance(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const attendance = manager.getRepository(AttendanceRecord);
    const payload = dto.payload;
    const existing =
      (await attendance.findOne({
        where: {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
      })) ??
      (await attendance.findOne({
        where: {
          tenantId: payload["tenantId"] as string,
          schoolId: payload["schoolId"] as string,
          campusId:
            (payload["campusId"] as string | undefined) ?? IsNull(),
          studentId: payload["studentId"] as string,
          classArmId: payload["classArmId"] as string,
          attendanceDate: payload["attendanceDate"] as string,
          deleted: false,
        },
      }));

    if (dto.operation === "delete") {
      await this.assertNotStale(
        attendance,
        user,
        existing?.id ?? dto.entity_id,
        dto.payload,
        "attendance_record",
      );
      if (existing) {
        await attendance.update(
          {
            id: existing.id,
            tenantId: user.tenantId!,
            schoolId: user.schoolId!,
          },
          {
            deleted: true,
            serverRevision: await this.nextServerRevision(manager),
            syncStatus: "synced",
          },
        );
        return existing.id;
      }
      return dto.entity_id;
    }

    if (dto.operation !== "create") {
      await this.assertNotStale(
        attendance,
        user,
        existing?.id ?? dto.entity_id,
        payload,
        "attendance_record",
      );
    }
    const canonicalEntityId = existing?.id ?? dto.entity_id;
    await attendance.save(
      attendance.create({
        id: canonicalEntityId,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        campusId: (payload["campusId"] as string | undefined) ?? null,
        studentId: payload["studentId"] as string,
        classArmId: payload["classArmId"] as string,
        academicYearId: payload["academicYearId"] as string,
        termId: payload["termId"] as string,
        attendanceDate: payload["attendanceDate"] as string,
        status: payload["status"] as AttendanceRecord["status"],
        recordedByUserId:
          (payload["recordedByUserId"] as string | undefined) ?? null,
        serverRevision: await this.nextServerRevision(manager),
        syncStatus: "synced",
        deleted: false,
      }),
    );
    return canonicalEntityId;
  }

  private async upsertGradingScheme(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const gradingSchemes = manager.getRepository(GradingScheme);
    if (dto.operation === "delete") {
      await this.assertNotStale(
        gradingSchemes,
        user,
        dto.entity_id,
        dto.payload,
        "grading_scheme",
      );
      await gradingSchemes.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
        },
      );
      return dto.entity_id;
    }

    const payload = dto.payload;
    if (dto.operation !== "create") {
      await this.assertNotStale(
        gradingSchemes,
        user,
        dto.entity_id,
        payload,
        "grading_scheme",
      );
    }

    await gradingSchemes.save(
      gradingSchemes.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        name: payload["name"] as string,
        bands: payload["bands"] as object,
        isDefault: (payload["isDefault"] as boolean | undefined) ?? false,
        deleted: false,
        serverRevision: await this.nextServerRevision(manager),
      }),
    );
    return dto.entity_id;
  }

  private async upsertAcademicYear(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const academicYears = manager.getRepository(AcademicYear);
    if (dto.operation === "delete") {
      await this.assertNotStale(
        academicYears,
        user,
        dto.entity_id,
        dto.payload,
        "academic_year",
      );
      await academicYears.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
        },
      );
      return dto.entity_id;
    }

    const payload = dto.payload;
    if (dto.operation !== "create") {
      await this.assertNotStale(
        academicYears,
        user,
        dto.entity_id,
        payload,
        "academic_year",
      );
    }

    await academicYears.save(
      academicYears.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        label: payload["label"] as string,
        startDate: payload["startDate"] as string,
        endDate: payload["endDate"] as string,
        isCurrent: (payload["isCurrent"] as boolean | undefined) ?? false,
        deleted: false,
        serverRevision: await this.nextServerRevision(manager),
      }),
    );
    return dto.entity_id;
  }

  private async upsertTerm(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const terms = manager.getRepository(Term);
    if (dto.operation === "delete") {
      await this.assertNotStale(
        terms,
        user,
        dto.entity_id,
        dto.payload,
        "term",
      );
      await terms.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
        },
      );
      return dto.entity_id;
    }

    const payload = dto.payload;
    if (dto.operation !== "create") {
      await this.assertNotStale(terms, user, dto.entity_id, payload, "term");
    }

    await terms.save(
      terms.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        academicYearId: payload["academicYearId"] as string,
        name: payload["name"] as string,
        termNumber: payload["termNumber"] as number,
        startDate: payload["startDate"] as string,
        endDate: payload["endDate"] as string,
        isCurrent: (payload["isCurrent"] as boolean | undefined) ?? false,
        deleted: false,
        serverRevision: await this.nextServerRevision(manager),
      }),
    );
    return dto.entity_id;
  }

  private async upsertClassLevel(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const classLevels = manager.getRepository(ClassLevel);
    if (dto.operation === "delete") {
      await this.assertNotStale(
        classLevels,
        user,
        dto.entity_id,
        dto.payload,
        "class_level",
      );
      await classLevels.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
        },
      );
      return dto.entity_id;
    }

    const payload = dto.payload;
    if (dto.operation !== "create") {
      await this.assertNotStale(
        classLevels,
        user,
        dto.entity_id,
        payload,
        "class_level",
      );
    }

    await classLevels.save(
      classLevels.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        name: payload["name"] as string,
        sortOrder: (payload["sortOrder"] as number | undefined) ?? 0,
        deleted: false,
        serverRevision: await this.nextServerRevision(manager),
      }),
    );
    return dto.entity_id;
  }

  private async upsertClassArm(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const classArms = manager.getRepository(ClassArm);
    if (dto.operation === "delete") {
      await this.assertNotStale(
        classArms,
        user,
        dto.entity_id,
        dto.payload,
        "class_arm",
      );
      await classArms.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
        },
      );
      return dto.entity_id;
    }

    const payload = dto.payload;
    if (dto.operation !== "create") {
      await this.assertNotStale(
        classArms,
        user,
        dto.entity_id,
        payload,
        "class_arm",
      );
    }

    await classArms.save(
      classArms.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        classLevelId: payload["classLevelId"] as string,
        arm: payload["arm"] as string,
        displayName: payload["displayName"] as string,
        deleted: false,
        serverRevision: await this.nextServerRevision(manager),
      }),
    );
    return dto.entity_id;
  }

  private async upsertSubject(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const subjects = manager.getRepository(Subject);
    if (dto.operation === "delete") {
      await this.assertNotStale(
        subjects,
        user,
        dto.entity_id,
        dto.payload,
        "subject",
      );
      await subjects.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
        },
      );
      return dto.entity_id;
    }

    const payload = dto.payload;
    if (dto.operation !== "create") {
      await this.assertNotStale(
        subjects,
        user,
        dto.entity_id,
        payload,
        "subject",
      );
    }

    await subjects.save(
      subjects.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        name: payload["name"] as string,
        code: (payload["code"] as string | undefined) ?? null,
        deleted: false,
        serverRevision: await this.nextServerRevision(manager),
      }),
    );
    return dto.entity_id;
  }

  private async upsertSchool(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const schools = manager.getRepository(School);
    if (dto.operation === "delete") {
      await this.assertSchoolNotStale(
        schools,
        user,
        dto.entity_id,
        dto.payload,
        "school",
      );
      await schools.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
        },
      );
      return dto.entity_id;
    }

    const payload = dto.payload;
    if (dto.operation !== "create") {
      await this.assertSchoolNotStale(
        schools,
        user,
        dto.entity_id,
        payload,
        "school",
      );
    }

    await schools.save(
      schools.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        name: payload["name"] as string,
        shortName: (payload["shortName"] as string | undefined) ?? null,
        schoolType: payload["schoolType"] as School["schoolType"],
        address: (payload["address"] as string | undefined) ?? null,
        region: (payload["region"] as string | undefined) ?? null,
        district: (payload["district"] as string | undefined) ?? null,
        contactPhone: (payload["contactPhone"] as string | undefined) ?? null,
        contactEmail: (payload["contactEmail"] as string | undefined) ?? null,
        onboardingDefaults:
          (payload["onboardingDefaults"] as
            | Record<string, unknown>
            | undefined) ?? {},
        deleted: false,
        serverRevision: await this.nextServerRevision(manager),
      }),
    );
    return dto.entity_id;
  }

  private async assertSchoolNotStale(
    repository: Repository<School>,
    user: User,
    entityId: string,
    payload: Record<string, unknown>,
    entityType: string,
  ) {
    const baseServerRevision = this.parseBaseServerRevision(
      payload["baseServerRevision"],
      entityType,
    );
    const baseUpdatedAt = payload["baseUpdatedAt"] as string | undefined;

    if (baseServerRevision === undefined && !baseUpdatedAt) {
      return;
    }

    const existing = await repository.findOne({
      where: {
        id: entityId,
        tenantId: user.tenantId!,
      },
    });
    if (!existing) {
      return;
    }

    const existingRevision = this.revisionFor(existing);
    if (
      baseServerRevision !== undefined &&
      existingRevision > baseServerRevision
    ) {
      throw new ConflictException({
        code: "sync_conflict",
        conflictType: "stale_update",
        entityType,
        entityId,
        message: `Sync conflict for '${entityType}/${entityId}': server revision is newer than the offline update base.`,
        baseServerRevision,
        serverRevision: existingRevision,
        serverRecord: existing,
      });
    }

    if (!baseUpdatedAt) {
      return;
    }

    const clientTimestamp = Date.parse(baseUpdatedAt);
    if (Number.isNaN(clientTimestamp)) {
      throw new BadRequestException(
        `Sync payload has an invalid baseUpdatedAt for '${entityType}'.`,
      );
    }

    if (existing.updatedAt.getTime() > clientTimestamp) {
      throw new ConflictException({
        code: "sync_conflict",
        conflictType: "stale_update",
        entityType,
        entityId,
        message: `Sync conflict for '${entityType}/${entityId}': server record is newer than the offline update.`,
        baseUpdatedAt,
        baseServerRevision,
        serverRevision: existingRevision,
        serverUpdatedAt: existing.updatedAt.toISOString(),
        serverRecord: existing,
      });
    }
  }

  private async upsertCampus(
    manager: EntityManager,
    user: User,
    dto: SyncPushRequestDto,
  ) {
    const campuses = manager.getRepository(Campus);
    if (dto.operation === "delete") {
      await this.assertNotStale(
        campuses,
        user,
        dto.entity_id,
        dto.payload,
        "campus",
      );
      await campuses.update(
        {
          id: dto.entity_id,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
        {
          deleted: true,
          serverRevision: await this.nextServerRevision(manager),
        },
      );
      return dto.entity_id;
    }

    const payload = dto.payload;
    if (dto.operation !== "create") {
      await this.assertNotStale(
        campuses,
        user,
        dto.entity_id,
        payload,
        "campus",
      );
    }

    await campuses.save(
      campuses.create({
        id: dto.entity_id,
        tenantId: payload["tenantId"] as string,
        schoolId: payload["schoolId"] as string,
        name: payload["name"] as string,
        address: (payload["address"] as string | undefined) ?? null,
        contactPhone: (payload["contactPhone"] as string | undefined) ?? null,
        registrationCode:
          (payload["registrationCode"] as string | undefined) ?? null,
        deleted: false,
        serverRevision: await this.nextServerRevision(manager),
      }),
    );
    return dto.entity_id;
  }

  private async rowsForPull(
    user: User,
    entityType: SyncEntityType,
    since: number,
    take: number,
  ) {
    if (!user.tenantId || !user.schoolId) {
      throw new BadRequestException(
        "Authenticated user is missing tenant or school scope.",
      );
    }

    const schoolScope = {
      tenantId: user.tenantId,
      schoolId: user.schoolId,
    };

    switch (entityType) {
      case "student":
        return this.students.find({
          where: this.revisionScopedWhere(
            this.directCampusScopeWhere(user, schoolScope),
            since,
          ),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "staff":
        return this.staff.find({
          where: this.revisionScopedWhere(
            this.directCampusScopeWhere(user, schoolScope),
            since,
          ),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "applicant":
        return this.applicants.find({
          where: this.revisionScopedWhere(
            this.directCampusScopeWhere(user, schoolScope),
            since,
          ),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "attendance_record":
        return this.attendance.find({
          where: this.revisionScopedWhere(
            this.directCampusScopeWhere(user, schoolScope),
            since,
          ),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "guardian": {
        const studentIds = await this.campusStudentIds(user);
        if (studentIds.length == 0) {
          return [];
        }
        return this.guardians.find({
          where: this.revisionScopedWhere(
            {
              ...schoolScope,
              studentId: In(studentIds),
            },
            since,
          ),
          order: { serverRevision: "ASC" as const },
          take,
        });
      }
      case "enrollment": {
        const studentIds = await this.campusStudentIds(user);
        if (studentIds.length == 0) {
          return [];
        }
        return this.enrollments.find({
          where: this.revisionScopedWhere(
            {
              ...schoolScope,
              studentId: In(studentIds),
            },
            since,
          ),
          order: { serverRevision: "ASC" as const },
          take,
        });
      }
      case "fee_category":
        return this.feeCategories.find({
          where: this.revisionScopedWhere(schoolScope, since),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "fee_structure_item":
        return this.feeStructureItems.find({
          where: this.revisionScopedWhere(schoolScope, since),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "invoice":
        return this.invoices.find({
          where: this.revisionScopedWhere(
            this.directCampusScopeWhere(user, schoolScope),
            since,
          ),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "payment":
        return this.payments.find({
          where: this.revisionScopedWhere(
            this.directCampusScopeWhere(user, schoolScope),
            since,
          ),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "payment_reversal":
        return this.paymentReversals.find({
          where: this.revisionScopedWhere(
            this.directCampusScopeWhere(user, schoolScope),
            since,
          ),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "staff_teaching_assignment": {
        const staffIds = await this.campusStaffIds(user);
        if (staffIds.length == 0) {
          return [];
        }
        return this.staffAssignments.find({
          where: this.revisionScopedWhere(
            {
              ...schoolScope,
              staffId: In(staffIds),
            },
            since,
          ),
          order: { serverRevision: "ASC" as const },
          take,
        });
      }
      case "academic_year":
        return this.academicYears.find({
          where: this.revisionScopedWhere(schoolScope, since),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "term":
        return this.terms.find({
          where: this.revisionScopedWhere(schoolScope, since),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "class_level":
        return this.classLevels.find({
          where: this.revisionScopedWhere(schoolScope, since),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "class_arm":
        return this.classArms.find({
          where: this.revisionScopedWhere(schoolScope, since),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "subject":
        return this.subjects.find({
          where: this.revisionScopedWhere(schoolScope, since),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "school":
        return this.schools.find({
          where: this.revisionScopedWhere(
            { tenantId: user.tenantId, id: user.schoolId },
            since,
          ),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "campus":
        return this.campuses.find({
          where: this.revisionScopedWhere(
            user.campusId ? { ...schoolScope, id: user.campusId } : schoolScope,
            since,
          ),
          order: { serverRevision: "ASC" as const },
          take,
        });
      case "grading_scheme":
        return this.gradingSchemes.find({
          where: this.revisionScopedWhere(schoolScope, since),
          order: { serverRevision: "ASC" as const },
          take,
        });
    }
  }

  private revisionScopedWhere<T extends Record<string, unknown>>(
    scope: T,
    since: number,
  ) {
    return {
      ...scope,
      serverRevision: MoreThan(since),
    };
  }

  private directCampusScopeWhere(
    user: User,
    schoolScope: { tenantId: string; schoolId: string },
  ) {
    if (!user.campusId) {
      return schoolScope;
    }

    return {
      ...schoolScope,
      campusId: user.campusId,
    };
  }

  private async campusStudentIds(user: User) {
    if (!user.tenantId || !user.schoolId) {
      return [];
    }

    const students = await this.students.find({
      select: { id: true },
      where: this.directCampusScopeWhere(user, {
        tenantId: user.tenantId,
        schoolId: user.schoolId,
      }),
      order: { serverRevision: "ASC" as const },
    });
    return students.map((student) => student.id);
  }

  private async campusStaffIds(user: User) {
    if (!user.tenantId || !user.schoolId) {
      return [];
    }

    const staff = await this.staff.find({
      select: { id: true },
      where: this.directCampusScopeWhere(user, {
        tenantId: user.tenantId,
        schoolId: user.schoolId,
      }),
      order: { serverRevision: "ASC" as const },
    });
    return staff.map((member) => member.id);
  }

  private async assertStudentReferenceInScope(
    manager: EntityManager,
    user: User,
    studentId: string | undefined,
    entityType: string,
  ) {
    if (!studentId) {
      return;
    }

    const student = await manager.getRepository(Student).findOne({
      where: {
        id: studentId,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      },
    });
    if (
      !student ||
      student.tenantId !== user.tenantId ||
      student.schoolId !== user.schoolId ||
      (user.campusId && student.campusId !== user.campusId)
    ) {
      throw new BadRequestException(
        `Sync payload '${entityType}' references a student outside the authenticated scope.`,
      );
    }
  }

  private async assertStaffReferenceInScope(
    manager: EntityManager,
    user: User,
    staffId: string | undefined,
    entityType: string,
  ) {
    if (!staffId) {
      return;
    }

    const staff = await manager.getRepository(Staff).findOne({
      where: {
        id: staffId,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      },
    });
    if (
      !staff ||
      staff.tenantId !== user.tenantId ||
      staff.schoolId !== user.schoolId ||
      (user.campusId && staff.campusId !== user.campusId)
    ) {
      throw new BadRequestException(
        `Sync payload '${entityType}' references a staff member outside the authenticated scope.`,
      );
    }
  }

  private async assertCampusReferenceInScope(
    manager: EntityManager,
    user: User,
    campusId: string | undefined,
    entityType: string,
  ) {
    if (!campusId) {
      return;
    }

    if (user.campusId && campusId === user.campusId) {
      return;
    }

    const campus = await manager.getRepository(Campus).findOne({
      where: {
        id: campusId,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      },
    });
    if (
      !campus ||
      campus.tenantId !== user.tenantId ||
      campus.schoolId !== user.schoolId ||
      campus.deleted
    ) {
      throw new BadRequestException(
        `Sync payload '${entityType}' references a campus outside the authenticated school scope.`,
      );
    }
  }

  private async assertSchoolReferenceInScope<T extends object>(
    manager: EntityManager,
    user: User,
    entity: { new (): T },
    entityId: string | undefined,
    syncEntityType: string,
    referenceLabel: string,
  ) {
    if (!entityId) {
      return;
    }

    const row = (await manager.getRepository(entity).findOne({
      where: {
        id: entityId,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      } as never,
    })) as { tenantId?: string | null; schoolId?: string | null } | null;

    if (
      !row ||
      row.tenantId !== user.tenantId ||
      row.schoolId !== user.schoolId
    ) {
      throw new BadRequestException(
        `Sync payload '${syncEntityType}' references a ${referenceLabel} outside the authenticated school scope.`,
      );
    }
  }

  private async existingGuardianStudentId(
    manager: EntityManager,
    user: User,
    guardianId: string,
  ) {
    const guardian = await manager.getRepository(Guardian).findOne({
      where: {
        id: guardianId,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      },
    });
    return guardian?.studentId;
  }

  private async existingEnrollmentStudentId(
    manager: EntityManager,
    user: User,
    enrollmentId: string,
  ) {
    const enrollment = await manager.getRepository(Enrollment).findOne({
      where: {
        id: enrollmentId,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      },
    });
    return enrollment?.studentId;
  }

  private async existingFeeStructureCategoryId(
    manager: EntityManager,
    user: User,
    feeStructureItemId: string,
  ) {
    const item = await manager.getRepository(FeeStructureItem).findOne({
      where: {
        id: feeStructureItemId,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      },
    });
    return item?.feeCategoryId;
  }

  private async existingInvoiceStudentId(
    manager: EntityManager,
    user: User,
    invoiceId?: string,
  ) {
    if (!invoiceId) {
      return undefined;
    }
    const invoice = await manager.getRepository(Invoice).findOne({
      where: {
        id: invoiceId,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      },
    });
    return invoice?.studentId;
  }

  private async existingPaymentInvoiceId(
    manager: EntityManager,
    user: User,
    paymentId: string,
  ) {
    const payment = await manager.getRepository(Payment).findOne({
      where: {
        id: paymentId,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      },
    });
    return payment?.invoiceId;
  }

  private async existingPaymentReversalInvoiceId(
    manager: EntityManager,
    user: User,
    reversalId: string,
  ) {
    const reversal = await manager.getRepository(PaymentReversal).findOne({
      where: {
        id: reversalId,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      },
    });
    return reversal?.invoiceId;
  }

  private async assertPaymentDoesNotExceedOutstanding(
    manager: EntityManager,
    user: User,
    invoiceId: string,
    amount: number,
    excludePaymentId?: string,
  ) {
    const invoice = await manager.getRepository(Invoice).findOne({
      where: {
        id: invoiceId,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      },
    });
    if (!invoice) {
      throw new BadRequestException("Payment invoice was not found in scope.");
    }

    const postedPayments = await manager.getRepository(Payment).find({
      where: {
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
        invoiceId,
        status: PaymentStatus.Posted,
        deleted: false,
      },
    });
    const paymentIds = postedPayments
      .map((payment) => payment.id)
      .filter((id) => id !== excludePaymentId);
    const reversals = paymentIds.length
      ? await manager.getRepository(PaymentReversal).find({
          where: {
            tenantId: user.tenantId!,
            schoolId: user.schoolId!,
            paymentId: In(paymentIds),
            deleted: false,
          },
        })
      : [];
    const reversedPaymentIds = new Set(reversals.map((row) => row.paymentId));
    const appliedTotal = postedPayments
      .filter(
        (payment) =>
          payment.id !== excludePaymentId &&
          !reversedPaymentIds.has(payment.id),
      )
      .reduce((sum, payment) => sum + Number(payment.amount), 0);
    if (appliedTotal + amount > Number(invoice.totalAmount) + 0.0001) {
      throw new BadRequestException(
        "Payment amount exceeds the outstanding invoice balance.",
      );
    }
  }

  private async existingAttendanceStudentId(
    manager: EntityManager,
    user: User,
    attendanceId: string,
  ) {
    const attendance = await manager.getRepository(AttendanceRecord).findOne({
      where: {
        id: attendanceId,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      },
    });
    return attendance?.studentId;
  }

  private async existingStaffAssignmentStaffId(
    manager: EntityManager,
    user: User,
    assignmentId: string,
  ) {
    const assignment = await manager
      .getRepository(StaffTeachingAssignment)
      .findOne({
        where: {
          id: assignmentId,
          tenantId: user.tenantId!,
          schoolId: user.schoolId!,
        },
      });
    return assignment?.staffId;
  }

  private async nextServerRevision(manager: EntityManager) {
    const result = (await manager.query(
      "SELECT nextval('sync_server_revision_seq')::bigint AS revision",
    )) as { revision: string | number }[];
    return Number(result[0].revision);
  }

  private isDirectCampusScopedEntity(entityType: SyncEntityType) {
    return [
      "student",
      "staff",
      "applicant",
      "attendance_record",
      "invoice",
      "payment",
      "payment_reversal",
    ].includes(entityType);
  }

  private toSyncRecord(
    entityType: SyncEntityType,
    row:
      | AcademicYear
      | Term
      | ClassLevel
      | ClassArm
      | Subject
      | School
      | Campus
      | GradingScheme
      | Student
      | Guardian
      | Enrollment
      | FeeCategory
      | FeeStructureItem
      | Invoice
      | Payment
      | PaymentReversal
      | Staff
      | StaffTeachingAssignment
      | Applicant
      | AttendanceRecord,
  ) {
    return {
      entity_type: entityType,
      record: {
        ...row,
        createdAt: row.createdAt.toISOString(),
        updatedAt: row.updatedAt.toISOString(),
      },
      revision: this.revisionFor(row),
    };
  }

  private revisionFor(row: {
    updatedAt: Date;
    serverRevision?: number | string;
  }) {
    if (row.serverRevision !== undefined && row.serverRevision !== null) {
      return Number(row.serverRevision);
    }

    return row.updatedAt.getTime();
  }

  private hashSyncRequest(dto: SyncPushRequestDto) {
    return createHash("sha256")
      .update(
        this.stableStringify({
          entityType: dto.entity_type,
          entityId: dto.entity_id,
          operation: dto.operation,
          payload: dto.payload,
        }),
      )
      .digest("hex");
  }

  private stableStringify(value: unknown): string {
    if (Array.isArray(value)) {
      return `[${value.map((item) => this.stableStringify(item)).join(",")}]`;
    }

    if (value && typeof value === "object") {
      return `{${Object.keys(value as Record<string, unknown>)
        .sort()
        .map(
          (key) =>
            `${JSON.stringify(key)}:${this.stableStringify(
              (value as Record<string, unknown>)[key],
            )}`,
        )
        .join(",")}}`;
    }

    return JSON.stringify(value);
  }

  private isIdempotencyUniqueViolation(error: unknown) {
    const driverError = (
      error as QueryFailedError & {
        driverError?: { code?: string; constraint?: string };
      }
    )?.driverError;
    return (
      driverError?.code === "23505" &&
      [
        "idx_sync_push_receipts_idempotency_scope",
        "sync_push_receipts_idempotency_key_key",
      ].includes(driverError.constraint ?? "")
    );
  }

  private isPendingReconciliationUniqueViolation(error: unknown) {
    const driverError = (
      error as QueryFailedError & {
        driverError?: { code?: string; constraint?: string };
      }
    )?.driverError;
    return (
      driverError?.code === "23505" &&
      driverError.constraint ===
        "idx_sync_reconciliation_requests_target_pending"
    );
  }

  private normalizeRequestedCampusScope(user: User, campusId?: string) {
    if (user.role === "support_technician") {
      if (!user.campusId) {
        throw new BadRequestException(
          "Support technician is missing campus scope.",
        );
      }
      if (campusId && campusId !== user.campusId) {
        throw new BadRequestException(
          "Support technician cannot request reconciliation outside the active campus.",
        );
      }
      return user.campusId;
    }

    return campusId ?? user.campusId ?? null;
  }

  private pendingReconciliationScopeWhere(
    user: User,
    deviceId: string,
  ): FindOptionsWhere<SyncReconciliationRequest> {
    const where: FindOptionsWhere<SyncReconciliationRequest> = {
      tenantId: user.tenantId!,
      schoolId: user.schoolId!,
      targetDeviceId: deviceId,
      status: "pending",
    };

    if (user.campusId) {
      where["campusId"] = user.campusId;
    }

    return where;
  }

  private toReconciliationSummary(request: SyncReconciliationRequest) {
    return {
      id: request.id,
      tenantId: request.tenantId,
      schoolId: request.schoolId,
      campusId: request.campusId,
      targetDeviceId: request.targetDeviceId,
      reason: request.reason,
      status: request.status,
      requestedAt: request.requestedAt.toISOString(),
      acknowledgedAt: request.acknowledgedAt?.toISOString() ?? null,
    };
  }

  private async assertNotStale<
    T extends {
      id: string;
      tenantId: string;
      schoolId: string;
      updatedAt: Date;
      serverRevision?: number | string;
    },
  >(
    repository: Repository<T>,
    user: User,
    entityId: string,
    payload: Record<string, unknown>,
    entityType: string,
  ) {
    const baseServerRevision = this.parseBaseServerRevision(
      payload["baseServerRevision"],
      entityType,
    );
    const baseUpdatedAt = payload["baseUpdatedAt"] as string | undefined;

    if (baseServerRevision === undefined && !baseUpdatedAt) {
      return;
    }

    const existing = await repository.findOne({
      where: {
        id: entityId,
        tenantId: user.tenantId!,
        schoolId: user.schoolId!,
      } as never,
    });
    if (!existing) {
      return;
    }

    const existingRevision = this.revisionFor(existing);
    if (
      baseServerRevision !== undefined &&
      existingRevision > baseServerRevision
    ) {
      throw new ConflictException({
        code: "sync_conflict",
        conflictType: "stale_update",
        entityType,
        entityId,
        message: `Sync conflict for '${entityType}/${entityId}': server revision is newer than the offline update base.`,
        baseServerRevision,
        serverRevision: existingRevision,
        serverRecord: existing,
      });
    }

    if (!baseUpdatedAt) {
      return;
    }

    const clientTimestamp = Date.parse(baseUpdatedAt);
    if (Number.isNaN(clientTimestamp)) {
      throw new BadRequestException(
        `Sync payload has an invalid baseUpdatedAt for '${entityType}'.`,
      );
    }

    if (existing.updatedAt.getTime() > clientTimestamp) {
      throw new ConflictException({
        code: "sync_conflict",
        conflictType: "stale_update",
        entityType,
        entityId,
        message: `Sync conflict for '${entityType}/${entityId}': server record is newer than the offline update.`,
        baseUpdatedAt,
        baseServerRevision,
        serverRevision: existingRevision,
        serverUpdatedAt: existing.updatedAt.toISOString(),
        serverRecord: existing,
      });
    }
  }

  private parseBaseServerRevision(value: unknown, entityType: string) {
    if (value === undefined || value === null || value === "") {
      return undefined;
    }

    const revision = Number(value);
    if (!Number.isInteger(revision) || revision < 0) {
      throw new BadRequestException(
        `Sync payload has an invalid baseServerRevision for '${entityType}'.`,
      );
    }

    return revision;
  }

  private assertRoleAllowedForSyncOperation(
    user: User,
    operation:
      | "pull"
      | "push"
      | "create_reconciliation_request"
      | "view_reconciliation_request"
      | "acknowledge_reconciliation",
    entityType?: SyncEntityType,
  ) {
    const role = user.role;

    if (operation === "pull" || operation === "push") {
      if (entityType && this.roleCanSyncEntity(role, entityType)) {
        return;
      }

      throw new ForbiddenException(
        `Role '${role}' cannot ${operation} sync data for '${entityType ?? "unknown"}' in this workspace.`,
      );
    }

    if (
      role === "admin" ||
      role === "cashier" ||
      role === "teacher" ||
      role === "support_admin" ||
      role === "support_technician"
    ) {
      return;
    }

    throw new ForbiddenException(
      `Role '${role}' cannot ${operation.replaceAll("_", " ")} in this workspace.`,
    );
  }

  private roleCanSyncEntity(role: string, entityType: SyncEntityType) {
    if (role === "admin" || role === "support_admin") {
      return true;
    }

    if (role === "teacher") {
      return [
        "student",
        "guardian",
        "enrollment",
        "staff",
        "staff_teaching_assignment",
        "applicant",
        "attendance_record",
        "academic_year",
        "term",
        "class_level",
        "class_arm",
        "subject",
        "school",
        "campus",
        "grading_scheme",
      ].includes(entityType);
    }

    if (role === "cashier") {
      return [
        "student",
        "enrollment",
        "fee_category",
        "fee_structure_item",
        "invoice",
        "payment",
        "payment_reversal",
        "academic_year",
        "term",
        "class_level",
        "class_arm",
        "school",
        "campus",
      ].includes(entityType);
    }

    return false;
  }
}
