import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { FindOptionsWhere, IsNull, Repository } from 'typeorm';
import { AuditService } from '../audit/audit.service';
import { User } from '../users/user.entity';
import { UserRole } from '../users/user-role.enum';
import { Device } from './device.entity';

@Injectable()
export class DevicesService {
  constructor(
    @InjectRepository(Device)
    private readonly devices: Repository<Device>,
    private readonly audit: AuditService,
  ) {}

  async listTrustedDevices(user: User) {
    return (await this.devices.find({
      where: this.deviceScopeWhere(user),
      order: { updatedAt: 'DESC', createdAt: 'DESC' },
    })).map((device) => this.toDeviceSummary(device));
  }

  async revokeTrustedDevice(user: User, deviceId: string) {
    const device = await this.devices.findOne({
      where: {
        id: deviceId,
        ...this.deviceScopeWhere(user),
      },
    });
    if (!device) {
      throw new NotFoundException('Trusted device not found in this scope.');
    }

    await this.devices.update(device.id, { isActive: false });
    await this.audit.record({
      tenantId: user.tenantId!,
      schoolId: user.schoolId!,
      campusId: device.campusId,
      actorUserId: user.id,
      eventType: 'devices.trusted_device_revoked',
      entityType: 'device',
      entityId: device.id,
      metadata: {
        deviceName: device.deviceName,
        deviceFingerprint: device.deviceFingerprint,
        mode: 'scoped_admin_revoke',
      },
    });
    return this.toDeviceSummary({
      ...device,
      isActive: false,
    } as Device);
  }

  async revokeCurrentTrustedDevice(user: User, deviceFingerprint: string) {
    const device = await this.devices.findOne({
      where: {
        deviceFingerprint,
        registeredByUserId: user.id,
        ...this.deviceOwnerScopeWhere(user),
      },
    });
    if (!device) {
      throw new NotFoundException('Trusted device not found in this scope.');
    }

    await this.devices.update(device.id, { isActive: false });
    await this.audit.record({
      tenantId: user.tenantId!,
      schoolId: user.schoolId!,
      campusId: device.campusId,
      actorUserId: user.id,
      eventType: 'devices.current_trusted_device_revoked',
      entityType: 'device',
      entityId: device.id,
      metadata: {
        deviceName: device.deviceName,
        deviceFingerprint: device.deviceFingerprint,
        mode: 'self_revoke',
      },
    });
    return this.toDeviceSummary({
      ...device,
      isActive: false,
    } as Device);
  }

  private deviceScopeWhere(user: User): FindOptionsWhere<Device> {
    if (!user.tenantId || !user.schoolId) {
      throw new NotFoundException('Trusted device scope is not available.');
    }

    const baseScope = {
      tenantId: user.tenantId,
      schoolId: user.schoolId,
      isActive: true,
    };

    if (user.role === UserRole.SupportAdmin) {
      return baseScope;
    }

    if (user.campusId) {
      return {
        ...baseScope,
        campusId: user.campusId,
      };
    }

    return baseScope;
  }

  private deviceOwnerScopeWhere(user: User): FindOptionsWhere<Device> {
    if (!user.tenantId || !user.schoolId) {
      throw new NotFoundException('Trusted device scope is not available.');
    }

    return {
      tenantId: user.tenantId,
      schoolId: user.schoolId,
      campusId: user.campusId ?? IsNull(),
      isActive: true,
    };
  }

  private toDeviceSummary(device: Device) {
    return {
      id: device.id,
      deviceName: device.deviceName,
      deviceFingerprint: device.deviceFingerprint,
      tenantId: device.tenantId,
      schoolId: device.schoolId,
      campusId: device.campusId,
      registeredByUserId: device.registeredByUserId,
      isActive: device.isActive,
      lastUsedAt: device.lastUsedAt?.toISOString() ?? null,
      createdAt: device.createdAt.toISOString(),
      updatedAt: device.updatedAt.toISOString(),
    };
  }
}
