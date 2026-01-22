import { Module } from '@nestjs/common';
import { DemoService } from './demo.service';
import { DemoController } from './demo.controller';
import { KafkaModule } from '../kafka/kafka.module';
import { WebsocketModule } from '../websocket/websocket.module';

@Module({
  imports: [KafkaModule, WebsocketModule],
  providers: [DemoService],
  controllers: [DemoController],
})
export class DemoModule {}
