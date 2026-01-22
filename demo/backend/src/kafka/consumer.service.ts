import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { Kafka, Consumer, EachMessagePayload } from 'kafkajs';
import { EventsGateway } from '../websocket/events.gateway';
import { MetricsService } from '../metrics/metrics.service';

export interface ConsumerConfig {
  topic: string;
  groupId: string;
  fromBeginning?: boolean;
  onMessage: (payload: EachMessagePayload) => Promise<void>;
}

@Injectable()
export class ConsumerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ConsumerService.name);
  private kafka: Kafka;
  private consumers: Map<string, Consumer> = new Map();

  constructor(
    private readonly eventsGateway: EventsGateway,
    private readonly metricsService: MetricsService,
  ) {
    const brokers = (process.env.KAFKA_BROKERS || 'localhost:9092').split(',');
    
    this.kafka = new Kafka({
      clientId: 'nestjs-consumer',
      brokers,
      retry: {
        initialRetryTime: 300,
        retries: 10,
      },
    });
  }

  async onModuleInit() {
    // Start 3 consumers in the SAME group to demonstrate load balancing
    const groupId = 'demo-shared-group'; 
    
    // We run 3 consumers for the same topic
    for (let i = 1; i <= 3; i++) {
        const consumerId = `Consumer-${i}`;
        
        await this.startConsumer({
          topic: 'demo-events',
          groupId,
          fromBeginning: false,
          instanceId: i, // Custom prop to identify
          onMessage: async (payload) => {
            const start = Date.now();
            const message = {
              topic: payload.topic,
              partition: payload.partition,
              offset: payload.message.offset,
              key: payload.message.key?.toString(),
              value: payload.message.value?.toString(),
              timestamp: payload.message.timestamp,
              headers: payload.message.headers,
            };

            this.logger.log(`[${consumerId}] Processing P:${message.partition} O:${message.offset}`);
            
            // Record Metrics
            this.metricsService.incrementMessagesConsumed(payload.topic, groupId);
            
            // Broadcast to WebSocket clients
            this.eventsGateway.broadcastMessage({
              type: 'kafka-message',
              consumerGroup: groupId,
              consumerId: consumerId, // Pass identifying info
              ...message,
            });

            // Mock processing time observation
            const duration = (Date.now() - start) / 1000;
            this.metricsService.observeMessageProcessingDuration(payload.topic, groupId, duration);
          },
        });
    }

    this.logger.log('✅ All Kafka Consumers started successfully');
  }

  async onModuleDestroy() {
    for (const [key, consumer] of this.consumers.entries()) {
      await consumer.disconnect();
      this.logger.log(`Consumer instance ${key} disconnected`);
    }
  }

  async startConsumer(config: ConsumerConfig & { instanceId?: number }): Promise<void> {
    const consumer = this.kafka.consumer({ 
      groupId: config.groupId,
      sessionTimeout: 30000,
      heartbeatInterval: 3000,
    });

    await consumer.connect();
    await consumer.subscribe({ 
      topic: config.topic, 
      fromBeginning: config.fromBeginning || false 
    });

    await consumer.run({
      eachMessage: config.onMessage,
    });

    // Use a unique key for the map (GroupID + InstanceID or Random)
    const mapKey = `${config.groupId}-${config.instanceId || Math.random()}`;
    this.consumers.set(mapKey, consumer);
    this.logger.log(`✅ Consumer ${config.instanceId ? '#' + config.instanceId : ''} joined group ${config.groupId}`);
  }

  async seek(consumerName: string, request: { topic: string; partition: number; offset: string }): Promise<boolean> {
      // Find the consumer instance. 
      // Our keys are like "demo-shared-group-1" for Consumer-1 (instanceId=1)
      // consumerName input is expected to be "Consumer-1", "Consumer-2", etc.
      
      const instanceId = consumerName.replace('Consumer-', '');
      const mapKey = `demo-shared-group-${instanceId}`;
      const consumer = this.consumers.get(mapKey);

      if (!consumer) {
          this.logger.warn(`Consumer ${consumerName} (key: ${mapKey}) not found for seek operation`);
          return false;
      }

      this.logger.log(`Seeking ${consumerName} to ${request.topic} P:${request.partition} O:${request.offset}`);
      consumer.seek({
          topic: request.topic,
          partition: request.partition,
          offset: request.offset,
      });
      return true;
  }
}
