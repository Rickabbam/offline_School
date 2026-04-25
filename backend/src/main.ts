import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
import { ApiExceptionFilter } from './common/filters/api-exception.filter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  app.useGlobalFilters(new ApiExceptionFilter());

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  console.log(`Backend running on http://localhost:${port}`);
  console.log(`Health check: http://localhost:${port}/health`);
}

bootstrap();
