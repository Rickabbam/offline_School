import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditModule } from '../audit/audit.module';
import { User } from '../users/user.entity';
import { OnboardingController } from './onboarding.controller';
import { OnboardingService } from './onboarding.service';

@Module({
  imports: [AuditModule, TypeOrmModule.forFeature([User])],
  controllers: [OnboardingController],
  providers: [OnboardingService],
})
export class OnboardingModule {}
