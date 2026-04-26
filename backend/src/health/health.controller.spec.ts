import { HealthCheckError } from '@nestjs/terminus';
import { HealthController } from './health.controller';

describe('HealthController', () => {
  function createController(options?: {
    pendingMigrations?: boolean;
    redisPing?: () => Promise<string>;
  }) {
    const health = {
      check: jest.fn(async (indicators: Array<() => Promise<unknown> | unknown>) =>
        Promise.all(indicators.map((indicator) => indicator())),
      ),
    };
    const db = {
      pingCheck: jest.fn(async () => ({ database: { status: 'up' } })),
    };
    const memory = {
      checkHeap: jest.fn(async () => ({ memory_heap: { status: 'up' } })),
    };
    const dataSource = {
      showMigrations: jest.fn(async () => options?.pendingMigrations ?? false),
    };
    const redis = {
      ping: jest.fn(options?.redisPing ?? (async () => 'PONG')),
    };

    return {
      controller: new HealthController(
        health as never,
        db as never,
        memory as never,
        dataSource as never,
        redis as never,
      ),
      health,
      db,
      memory,
      dataSource,
      redis,
    };
  }

  it('checks database, migration state, memory, and Redis in one health response', async () => {
    const { controller, dataSource, redis } = createController();

    const result = await controller.check();

    expect(result).toEqual([
      { database: { status: 'up' } },
      { migrations: { status: 'up', pending: false } },
      { memory_heap: { status: 'up' } },
      { redis: { status: 'up' } },
    ]);
    expect(dataSource.showMigrations).toHaveBeenCalledTimes(1);
    expect(redis.ping).toHaveBeenCalledTimes(1);
  });

  it('fails health when TypeORM migrations are pending', async () => {
    const { controller } = createController({ pendingMigrations: true });

    await expect(controller.check()).rejects.toThrow(HealthCheckError);
  });
});
