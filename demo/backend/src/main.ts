import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    cors: true,
  });

  // Enable CORS for frontend
  app.enableCors({
    origin: '*',
    credentials: true,
  });

  const port = process.env.PORT || 3000;
  await app.listen(port);
  
  console.log(`🚀 NestJS Backend running on: http://localhost:${port}`);
  console.log(`📊 Metrics available at: http://localhost:${port}/metrics`);
  console.log(`🔌 WebSocket server ready`);
}

bootstrap();
