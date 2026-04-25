import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditModule } from '../audit/audit.module';
import { DevicesController } from './devices.controller';
import { Device } from './device.entity';
import { DevicesService } from './devices.service';

@Module({
  imports: [AuditModule, TypeOrmModule.forFeature([Device])],
  providers: [DevicesService],
  controllers: [DevicesController],
  exports: [TypeOrmModule, DevicesService],
})
export class DevicesModule {}
