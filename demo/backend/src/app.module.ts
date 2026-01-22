import { Module } from '@nestjs/common';
import { KafkaModule } from './kafka/kafka.module';
import { WebsocketModule } from './websocket/websocket.module';
import { MetricsModule } from './metrics/metrics.module';
import { DemoModule } from './demo/demo.module';

@Module({
  imports: [
    KafkaModule,
    WebsocketModule,
    MetricsModule,
    DemoModule,
  ],
})
export class AppModule {}
