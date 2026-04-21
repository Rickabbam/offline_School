import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { validate } from './config/env.validation';
import { DatabaseModule } from './database/database.module';
import { RedisModule } from './redis/redis.module';
import { HealthModule } from './health/health.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { DevicesModule } from './devices/devices.module';
import { TenantsModule } from './tenants/tenants.module';
import { SchoolsModule } from './schools/schools.module';
import { CampusesModule } from './campuses/campuses.module';
import { AcademicModule } from './academic/academic.module';
import { StudentsModule } from './students/students.module';
import { StaffModule } from './staff/staff.module';
import { AdmissionsModule } from './admissions/admissions.module';
import { AttendanceModule } from './attendance/attendance.module';
import { OnboardingModule } from './onboarding/onboarding.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate,
    }),
    DatabaseModule,
    RedisModule,
    HealthModule,
    AuthModule,
    UsersModule,
    DevicesModule,
    TenantsModule,
    SchoolsModule,
    CampusesModule,
    AcademicModule,
    StudentsModule,
    StaffModule,
    AdmissionsModule,
    AttendanceModule,
    OnboardingModule,
  ],
})
export class AppModule {}
