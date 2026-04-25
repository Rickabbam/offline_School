import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';
import { AuditService } from '../audit/audit.service';
import { User } from '../users/user.entity';
import { Device } from '../devices/device.entity';
import { LoginDto } from './dto/login.dto';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { JwtPayload } from './jwt.strategy';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(Device) private readonly devices: Repository<Device>,
    private readonly jwt: JwtService,
    private readonly audit: AuditService,
  ) {}

  async login(dto: LoginDto) {
    const user = await this.users.findOne({
      where: { email: dto.email.toLowerCase(), deleted: false },
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('Invalid email or password.');
    }

    const passwordMatch = await bcrypt.compare(dto.password, user.passwordHash);
    if (!passwordMatch) {
      throw new UnauthorizedException('Invalid email or password.');
    }

    const trustedDeviceFingerprint = dto.deviceFingerprint
      ? await this.resolveTrustedDeviceFingerprintForLogin(
          user,
          dto.deviceFingerprint,
        )
      : null;

    return this.issueTokenPair(user, trustedDeviceFingerprint);
  }

  async refreshToken(refreshToken: string, deviceFingerprint?: string) {
    let payload: JwtPayload;
    try {
      payload = this.jwt.verify<JwtPayload>(refreshToken);
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token.');
    }

    if (payload.tokenType !== 'refresh') {
      throw new UnauthorizedException('Invalid refresh token.');
    }

    const user = await this.users.findOne({
      where: { id: payload.sub, deleted: false, isActive: true },
    });
    if (!user) throw new UnauthorizedException('User not found.');
    if (payload.sessionVersion !== user.sessionVersion) {
      throw new UnauthorizedException(
        'Refresh token session is no longer active.',
      );
    }

    if (payload.deviceFingerprint) {
      if (!deviceFingerprint || deviceFingerprint != payload.deviceFingerprint) {
        throw new UnauthorizedException(
          'Refresh token is bound to a different trusted device.',
        );
      }
      await this.assertTrustedDeviceFingerprint(user, payload.deviceFingerprint);
      return this.issueTokenPair(user, payload.deviceFingerprint);
    }

    const trustedDeviceFingerprint = deviceFingerprint
      ? await this.resolveTrustedDeviceFingerprint(user, deviceFingerprint)
      : null;
    return this.issueTokenPair(user, trustedDeviceFingerprint);
  }

  async offlineLogin(deviceFingerprint: string, offlineToken: string) {
    const user = await this.validateOfflineToken(deviceFingerprint, offlineToken);
    return this.issueTokenPair(user, deviceFingerprint);
  }

  async registerDevice(userId: string, dto: RegisterDeviceDto) {
    const user = await this.users.findOne({
      where: { id: userId, deleted: false, isActive: true },
    });
    if (!user) throw new NotFoundException('User not found.');
    if (!user.tenantId || !user.schoolId) {
      throw new BadRequestException(
        'Trusted device registration requires an assigned tenant and school.',
      );
    }

    const rawOfflineToken = uuidv4() + '-' + uuidv4();
    const offlineTokenHash = await bcrypt.hash(rawOfflineToken, 12);
    const existing = await this.devices.findOne({
      where: { deviceFingerprint: dto.deviceFingerprint },
    });

    let device: Device;
    let registrationMode = 'new_registration';
    if (existing) {
      if (existing.registeredByUserId !== userId && existing.isActive) {
        throw new BadRequestException('Device already registered.');
      }

      device = {
        ...existing,
        deviceName: dto.deviceName,
        offlineTokenHash,
        tenantId: user.tenantId,
        schoolId: user.schoolId,
        campusId: user.campusId,
        registeredByUserId: userId,
        isActive: true,
      };
      registrationMode =
        existing.registeredByUserId === userId
          ? 'credential_rotation'
          : 'reassigned_after_revoke';
    } else {
      device = this.devices.create({
        deviceName: dto.deviceName,
        deviceFingerprint: dto.deviceFingerprint,
        offlineTokenHash,
        tenantId: user.tenantId,
        schoolId: user.schoolId,
        campusId: user.campusId,
        registeredByUserId: userId,
      });
    }

    await this.devices.save(device);
    await this.audit.record({
      tenantId: user.tenantId,
      schoolId: user.schoolId,
      campusId: user.campusId,
      actorUserId: user.id,
      eventType: 'devices.trusted_device_registered',
      entityType: 'device',
      entityId: device.id,
      metadata: {
        deviceName: device.deviceName,
        deviceFingerprint: device.deviceFingerprint,
        mode: registrationMode,
      },
    });

    return {
      deviceId: device.id,
      offlineToken: rawOfflineToken,
    };
  }

  async logout(user: User, deviceFingerprint?: string) {
    const nextSessionVersion = user.sessionVersion + 1;
    await this.users.update(user.id, { sessionVersion: nextSessionVersion });

    if (deviceFingerprint != null && deviceFingerprint.trim().length > 0) {
      await this.devices.update(
        {
          deviceFingerprint: deviceFingerprint.trim(),
          registeredByUserId: user.id,
          isActive: true,
        },
        { lastUsedAt: new Date() },
      );
    }

    return {
      success: true,
      userId: user.id,
      sessionVersion: nextSessionVersion,
    };
  }

  async validateOfflineToken(deviceFingerprint: string, offlineToken: string) {
    const device = await this.devices.findOne({
      where: { deviceFingerprint, isActive: true },
      relations: ['registeredBy'],
    });

    if (!device) throw new UnauthorizedException('Device not recognised.');

    const match = await bcrypt.compare(offlineToken, device.offlineTokenHash);
    if (!match) throw new UnauthorizedException('Invalid offline token.');

    const user = device.registeredBy;
    if (!user || user.deleted || !user.isActive) {
      throw new UnauthorizedException('Trusted device user is no longer active.');
    }

    if (
      device.tenantId != user.tenantId ||
      device.schoolId != user.schoolId ||
      device.campusId != user.campusId
    ) {
      throw new UnauthorizedException(
        'Trusted device scope no longer matches the assigned user workspace.',
      );
    }

    await this.devices.update(device.id, { lastUsedAt: new Date() });

    return user;
  }

  private async resolveTrustedDeviceFingerprint(
    user: User,
    deviceFingerprint: string,
  ) {
    const device = await this.assertTrustedDeviceFingerprint(
      user,
      deviceFingerprint,
    );
    return device.deviceFingerprint;
  }

  private async assertTrustedDeviceFingerprint(
    user: User,
    deviceFingerprint: string,
  ) {
    const device = await this.devices.findOne({
      where: {
        deviceFingerprint,
        registeredByUserId: user.id,
        isActive: true,
      },
    });

    if (!device) {
      throw new UnauthorizedException('Trusted device not recognised.');
    }

    if (
      device.tenantId != user.tenantId ||
      device.schoolId != user.schoolId ||
      device.campusId != user.campusId
    ) {
      throw new UnauthorizedException(
        'Trusted device scope no longer matches the assigned user workspace.',
      );
    }

    return device;
  }

  private issueTokenPair(user: User, deviceFingerprint?: string | null) {
    const basePayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      tenantId: user.tenantId,
      schoolId: user.schoolId,
      campusId: user.campusId,
      sessionVersion: user.sessionVersion,
      deviceFingerprint: deviceFingerprint ?? null,
    };

    const accessToken = this.jwt.sign(
      { ...basePayload, tokenType: 'access' } satisfies JwtPayload,
      { expiresIn: '15m' },
    );
    const refreshToken = this.jwt.sign(
      { ...basePayload, tokenType: 'refresh' } satisfies JwtPayload,
      { expiresIn: '30d' },
    );

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        role: user.role,
        tenantId: user.tenantId,
        schoolId: user.schoolId,
        campusId: user.campusId,
      },
    };
  }

  private async resolveTrustedDeviceFingerprintForLogin(
    user: User,
    deviceFingerprint: string,
  ) {
    const device = await this.devices.findOne({
      where: {
        deviceFingerprint,
      },
    });

    if (!device || !device.isActive) {
      return null;
    }

    if (device.registeredByUserId !== user.id) {
      return null;
    }

    return this.resolveTrustedDeviceFingerprint(user, deviceFingerprint);
  }
}
