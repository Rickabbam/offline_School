import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EntityManager, FindOptionsWhere, QueryFailedError, Repository } from 'typeorm';
import { AuditLog } from './audit-log.entity';
import { User } from '../users/user.entity';
import { UserRole } from '../users/user-role.enum';
import { AuditQueryDto } from './dto/audit-query.dto';
import { OperatorAuditEventDto } from './dto/operator-audit-event.dto';

export interface AuditLogInput {
  tenantId: string;
  schoolId: string;
  campusId?: string | null;
  actorUserId?: string | null;
  eventType: string;
  entityType: string;
  entityId: string;
  metadata?: Record<string, unknown>;
  idempotencyKey?: string | null;
}

@Injectable()
export class AuditService {
  private static readonly supportVisibleEventPrefixes = [
    'desktop.',
    'devices.',
    'sync.',
    'onboarding.',
  ] as const;

  constructor(
    @InjectRepository(AuditLog)
    private readonly auditLogs: Repository<AuditLog>,
  ) {}

  async record(input: AuditLogInput, manager?: EntityManager) {
    const repo = manager?.getRepository(AuditLog) ?? this.auditLogs;
    try {
      return await repo.save(
        repo.create({
          tenantId: input.tenantId,
          schoolId: input.schoolId,
          campusId: input.campusId ?? null,
          actorUserId: input.actorUserId ?? null,
          eventType: input.eventType,
          entityType: input.entityType,
          entityId: input.entityId,
          metadataJson: input.metadata ?? {},
          idempotencyKey: input.idempotencyKey ?? null,
        }),
      );
    } catch (error) {
      if (input.idempotencyKey && this.isUniqueConstraint(error)) {
        const existing = await repo.findOne({
          where: {
            tenantId: input.tenantId,
            schoolId: input.schoolId,
            idempotencyKey: input.idempotencyKey,
          },
        });
        if (existing) {
          return existing;
        }
      }
      throw error;
    }
  }

  async listRecent(user: User, query: AuditQueryDto = {}) {
    if (
      user.role === UserRole.SupportTechnician &&
      query.eventType &&
      !this.isSupportVisibleEventType(query.eventType)
    ) {
      return [];
    }

    const where: FindOptionsWhere<AuditLog> = this.auditScopeWhere(user);
    if (query.eventType) {
      where.eventType = query.eventType;
    }
    if (query.entityType) {
      where.entityType = query.entityType;
    }

    const entries = await this.auditLogs.find({
      where,
      order: { createdAt: 'DESC' },
      take: query.limit ?? 20,
    });

    const visibleEntries =
      user.role === UserRole.SupportTechnician
        ? entries.filter((entry) => this.isSupportVisibleEventType(entry.eventType))
        : entries;

    return visibleEntries.map((entry) => this.toAuditSummary(entry));
  }

  async recordOperatorEvent(user: User, input: OperatorAuditEventDto) {
    if (!user.tenantId || !user.schoolId) {
      throw new NotFoundException('Audit scope is not available.');
    }
    const existing = await this.auditLogs.findOne({
      where: {
        tenantId: user.tenantId,
        schoolId: user.schoolId,
        idempotencyKey: input.idempotencyKey,
      },
    });
    if (existing) {
      return { accepted: true, replayed: true };
    }
    const campusId =
      user.role === UserRole.SupportTechnician ? user.campusId ?? null : null;
    await this.record({
      tenantId: user.tenantId,
      schoolId: user.schoolId,
      campusId,
      actorUserId: user.id,
      eventType: `desktop.${input.eventType}`,
      entityType: 'school_workspace',
      entityId: user.schoolId,
      metadata: input.metadata ?? {},
      idempotencyKey: input.idempotencyKey,
    });
    return { accepted: true, replayed: false };
  }

  private auditScopeWhere(user: User): FindOptionsWhere<AuditLog> {
    if (!user.tenantId || !user.schoolId) {
      throw new NotFoundException('Audit scope is not available.');
    }

    const baseScope: FindOptionsWhere<AuditLog> = {
      tenantId: user.tenantId,
      schoolId: user.schoolId,
    };

    if (user.role === UserRole.SupportTechnician && user.campusId) {
      return {
        ...baseScope,
        campusId: user.campusId,
      };
    }

    return baseScope;
  }

  private toAuditSummary(entry: AuditLog) {
    return {
      id: entry.id,
      tenantId: entry.tenantId,
      schoolId: entry.schoolId,
      campusId: entry.campusId,
      actorUserId: entry.actorUserId,
      eventType: entry.eventType,
      entityType: entry.entityType,
      entityId: entry.entityId,
      metadata: entry.metadataJson ?? {},
      createdAt: entry.createdAt.toISOString(),
    };
  }

  private isUniqueConstraint(error: unknown) {
    if (!(error instanceof QueryFailedError)) {
      return false;
    }
    const driverError = error.driverError as { code?: string } | undefined;
    return driverError?.code === '23505';
  }

  private isSupportVisibleEventType(eventType: string) {
    return AuditService.supportVisibleEventPrefixes.some((prefix) =>
      eventType.startsWith(prefix),
    );
  }
}
