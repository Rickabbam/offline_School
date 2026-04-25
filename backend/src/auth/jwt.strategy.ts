import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../users/user.entity';

export interface JwtPayload {
  sub: string;
  email: string;
  role: string;
  tenantId: string | null;
  schoolId: string | null;
  campusId: string | null;
  sessionVersion: number;
  deviceFingerprint?: string | null;
  tokenType: 'access' | 'refresh';
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    config: ConfigService,
    @InjectRepository(User) private readonly users: Repository<User>,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.getOrThrow<string>('JWT_SECRET'),
    });
  }

  async validate(payload: JwtPayload): Promise<User> {
    if (payload.tokenType !== 'access') {
      throw new UnauthorizedException('Invalid access token.');
    }

    const user = await this.users.findOne({
      where: { id: payload.sub, deleted: false, isActive: true },
    });
    if (!user) {
      throw new UnauthorizedException('User not found or inactive.');
    }

    if (
      user.tenantId !== payload.tenantId ||
      user.schoolId !== payload.schoolId ||
      user.campusId !== payload.campusId
    ) {
      throw new UnauthorizedException(
        'Token scope is stale. Sign in again to refresh workspace access.',
      );
    }

    if (user.sessionVersion !== payload.sessionVersion) {
      throw new UnauthorizedException(
        'Token session is no longer active. Sign in again.',
      );
    }

    return user;
  }
}
