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

    return this.issueTokenPair(user);
  }

  async refreshToken(refreshToken: string) {
    let payload: JwtPayload;
    try {
      payload = this.jwt.verify<JwtPayload>(refreshToken);
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token.');
    }

    const user = await this.users.findOne({
      where: { id: payload.sub, deleted: false, isActive: true },
    });
    if (!user) throw new UnauthorizedException('User not found.');

    return this.issueTokenPair(user);
  }

  async registerDevice(userId: string, dto: RegisterDeviceDto) {
    const user = await this.users.findOne({
      where: { id: userId, deleted: false },
    });
    if (!user) throw new NotFoundException('User not found.');

    const existing = await this.devices.findOne({
      where: { deviceFingerprint: dto.deviceFingerprint, isActive: true },
    });
    if (existing) {
      throw new BadRequestException('Device already registered.');
    }

    const rawOfflineToken = uuidv4() + '-' + uuidv4();
    const offlineTokenHash = await bcrypt.hash(rawOfflineToken, 12);

    const device = this.devices.create({
      deviceName: dto.deviceName,
      deviceFingerprint: dto.deviceFingerprint,
      offlineTokenHash,
      tenantId: user.tenantId,
      campusId: user.campusId,
      registeredByUserId: userId,
    });

    await this.devices.save(device);

    return {
      deviceId: device.id,
      offlineToken: rawOfflineToken,
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

    await this.devices.update(device.id, { lastUsedAt: new Date() });

    return device.registeredBy;
  }

  private issueTokenPair(user: User) {
    const payload: JwtPayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      tenantId: user.tenantId,
      schoolId: user.schoolId,
      campusId: user.campusId,
    };

    const accessToken = this.jwt.sign(payload, { expiresIn: '15m' });
    const refreshToken = this.jwt.sign(payload, { expiresIn: '30d' });

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
}
