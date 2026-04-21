import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Campus } from './campus.entity';
import { CampusesService } from './campuses.service';
import { CampusesController } from './campuses.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Campus])],
  providers: [CampusesService],
  controllers: [CampusesController],
  exports: [CampusesService],
})
export class CampusesModule {}
