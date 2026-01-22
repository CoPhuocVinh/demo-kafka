import { Injectable } from '@nestjs/common';
import { register, collectDefaultMetrics, Counter, Gauge, Histogram } from 'prom-client';

@Injectable()
export class MetricsService {
  private readonly messagesProducedCounter: Counter;
  private readonly messagesConsumedCounter: Counter;
  private readonly consumerLagGauge: Gauge;
  private readonly messageProcessingDuration: Histogram;
  private readonly activeWebSocketConnections: Gauge;

  constructor() {
    // Clear existing registers to prevent duplicate metric registration on hot reload
    register.clear();
    
    // Enable default metrics collection
    collectDefaultMetrics({ register });

    // Custom Kafka metrics
    this.messagesProducedCounter = new Counter({
      name: 'kafka_messages_produced_total',
      help: 'Total number of messages produced to Kafka',
      labelNames: ['topic'],
      registers: [register],
    });

    this.messagesConsumedCounter = new Counter({
      name: 'kafka_messages_consumed_total',
      help: 'Total number of messages consumed from Kafka',
      labelNames: ['topic', 'consumer_group'],
      registers: [register],
    });

    this.consumerLagGauge = new Gauge({
      name: 'kafka_consumer_lag',
      help: 'Current consumer lag',
      labelNames: ['topic', 'partition', 'consumer_group'],
      registers: [register],
    });

    this.messageProcessingDuration = new Histogram({
      name: 'kafka_message_processing_duration_seconds',
      help: 'Time taken to process Kafka messages',
      labelNames: ['topic', 'consumer_group'],
      buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5],
      registers: [register],
    });

    this.activeWebSocketConnections = new Gauge({
      name: 'websocket_active_connections',
      help: 'Number of active WebSocket connections',
      registers: [register],
    });
  }

  async getMetrics(): Promise<string> {
    return register.metrics();
  }

  get contentType(): string {
    return register.contentType;
  }

  // Helper methods for incrementing metrics
  incrementMessagesProduced(topic: string): void {
    this.messagesProducedCounter.inc({ topic });
  }

  incrementMessagesConsumed(topic: string, consumerGroup: string): void {
    this.messagesConsumedCounter.inc({ topic, consumer_group: consumerGroup });
  }

  setConsumerLag(topic: string, partition: number, consumerGroup: string, lag: number): void {
    this.consumerLagGauge.set({ topic, partition, consumer_group: consumerGroup }, lag);
  }

  observeMessageProcessingDuration(topic: string, consumerGroup: string, duration: number): void {
    this.messageProcessingDuration.observe({ topic, consumer_group: consumerGroup }, duration);
  }

  setActiveWebSocketConnections(count: number): void {
    this.activeWebSocketConnections.set(count);
  }

  incrementActiveWebSocketConnections(): void {
    this.activeWebSocketConnections.inc();
  }
  
  decrementActiveWebSocketConnections(): void {
    this.activeWebSocketConnections.dec();
  }
}
