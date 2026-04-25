import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Campus } from '../campuses/campus.entity';
import { Staff } from './staff.entity';
import { StaffService } from './staff.service';
import { StaffController } from './staff.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Staff, Campus])],
  providers: [StaffService],
  controllers: [StaffController],
  exports: [StaffService],
})
export class StaffModule {}
