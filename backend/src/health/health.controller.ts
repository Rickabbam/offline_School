import { Controller, Get } from '@nestjs/common';
import {
  HealthCheckService,
  HealthCheck,
  TypeOrmHealthIndicator,
  MemoryHealthIndicator,
  HealthCheckError,
  HealthIndicatorResult,
} from '@nestjs/terminus';
import { InjectDataSource } from '@nestjs/typeorm';
import { Inject } from '@nestjs/common';
import { DataSource } from 'typeorm';
import Redis from 'ioredis';
import { REDIS_CLIENT } from '../redis/redis.module';

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
    private memory: MemoryHealthIndicator,
    @InjectDataSource() private dataSource: DataSource,
    @Inject(REDIS_CLIENT) private redis: Redis,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.db.pingCheck('database'),
      () => this.checkMigrations(),
      () => this.memory.checkHeap('memory_heap', 300 * 1024 * 1024),
      () => this.checkRedis(),
    ]);
  }

  private async checkMigrations(): Promise<HealthIndicatorResult> {
    const pending = await this.dataSource.showMigrations();
    if (pending) {
      throw new HealthCheckError('Database migrations are pending', {
        migrations: {
          status: 'down' as const,
          pending: true,
        },
      });
    }

    return {
      migrations: {
        status: 'up' as const,
        pending: false,
      },
    };
  }

  private async checkRedis(): Promise<HealthIndicatorResult> {
    let timeout: NodeJS.Timeout | undefined;
    await Promise.race([
      this.redis.ping(),
      new Promise((_, reject) => {
        timeout = setTimeout(() => reject(new Error('Redis ping timed out')), 2000);
      }),
    ]).finally(() => {
      if (timeout) {
        clearTimeout(timeout);
      }
    });

    return { redis: { status: 'up' as const } };
  }
}
