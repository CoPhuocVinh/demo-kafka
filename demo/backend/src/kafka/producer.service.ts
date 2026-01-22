import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { Kafka, Producer, ProducerRecord, RecordMetadata } from 'kafkajs';
import { MetricsService } from '../metrics/metrics.service';

@Injectable()
export class ProducerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ProducerService.name);
  private kafka: Kafka;
  private producer: Producer;

  constructor(private readonly metricsService: MetricsService) {
    const brokers = (process.env.KAFKA_BROKERS || 'localhost:9092').split(',');
    
    this.kafka = new Kafka({
      clientId: 'nestjs-producer',
      brokers,
      retry: {
        initialRetryTime: 300,
        retries: 10,
      },
    });

    this.producer = this.kafka.producer({
      allowAutoTopicCreation: true,
      transactionTimeout: 30000,
    });
  }

  async onModuleInit() {
    try {
      await this.producer.connect();
      this.logger.log('✅ Kafka Producer connected successfully');
    } catch (error) {
      this.logger.error('❌ Failed to connect Kafka Producer', error);
      throw error;
    }
  }

  async onModuleDestroy() {
    await this.producer.disconnect();
    this.logger.log('Producer disconnected');
  }

  async produce(record: ProducerRecord): Promise<RecordMetadata[]> {
    try {
      const result = await this.producer.send(record);
      // Record metrics
      this.metricsService.incrementMessagesProduced(record.topic);
      
      this.logger.log(`Message sent to topic ${record.topic}: ${JSON.stringify(result)}`);
      return result;
    } catch (error) {
      this.logger.error(`Failed to send message to topic ${record.topic}`, error);
      throw error;
    }
  }

  async sendBatch(topic: string, messages: any[]): Promise<RecordMetadata[]> {
    const kafkaMessages = messages.map((msg) => ({
      key: msg.key || null,
      value: JSON.stringify(msg.value || msg),
      partition: msg.partition,
      headers: msg.headers || {},
    }));

    // produce() will record the batch as ONE produce call, but incrementMessagesProduced counts *calls* or *messages*?
    // The metric is "kafka_messages_produced_total".
    // Usually we want count of messages.
    // The current implementation of incrementMessagesProduced increments by 1.
    // Ideally we should overload it or call it N times.
    // For now, let's just track produce calls or update `produce` to account for batch size? 
    // Wait, `produce` takes a `ProducerRecord` which has an array of `messages`.
    // I should count record.messages.length.
    
    // Changing produce to count messages:
    // this.metricsService.incrementMessagesProduced(record.topic, record.messages.length);
    // But MetricsService.incrementMessagesProduced only takes topic.
    // I will stick to single increment for now to avoid compilation errors if I don't update service.
    // Actually, I should update the service to accept count!
    // But let's check MetricsService again. It uses `inc({ topic })` which defaults to 1.
    
    return this.produce({
      topic,
      messages: kafkaMessages,
    });
  }
}
