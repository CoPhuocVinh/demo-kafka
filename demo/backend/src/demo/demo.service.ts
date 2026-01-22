import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { ProducerService } from '../kafka/producer.service';
import { ConsumerService } from '../kafka/consumer.service';

interface DemoEvent {
  id: string;
  type: 'order' | 'payment' | 'shipment' | 'notification';
  userId: string;
  data: any;
  timestamp: string;
}

@Injectable()
export class DemoService implements OnModuleInit {
  private readonly logger = new Logger(DemoService.name);
  private intervalId: NodeJS.Timeout | undefined;
  private messageCount = 0;
  private isProducing = false;
  private partitionWeights = [1, 1, 1]; // Default equal weights for 3 partitions

  constructor(
    private readonly producerService: ProducerService,
    private readonly consumerService: ConsumerService
  ) {}

  async onModuleInit() {
    // Start producing demo events automatically
    // this.startProducing();
  }

  startProducing(): void {
    try {
      if (this.isProducing) {
        this.logger.warn('⚠️ Producer already running, restarting...');
        this.stopProducing();
      }

      const intervalEnv = process.env.DEMO_PRODUCER_INTERVAL_MS || '2000';
      const interval = parseInt(intervalEnv, 10);
      this.logger.log(`Starting production loop with interval ${interval}ms (Env: ${intervalEnv})...`);
      
      this.isProducing = true;

      this.intervalId = setInterval(async () => {
        if (!this.isProducing) {
             // Fail-safe: If flag is false, stop immediately (zombie killer)
             if (this.intervalId) clearInterval(this.intervalId);
             return; 
        }

        try {
          const event = this.generateDemoEvent();
          // this.logger.debug(`Generated event: ${event.id}`); // Optional debug

          const partition = this.getTargetPartition();
          
          await this.producerService.sendBatch('demo-events', [
            {
              key: event.id,
              value: event,
              partition,
            },
          ]);
          
          this.messageCount++;
          if (this.messageCount % 10 === 0) {
            this.logger.log(`📤 Produced ${this.messageCount} messages`);
          }
        } catch (error) {
          this.logger.error('Failed to produce demo event inside interval', error);
        }
      }, interval);

      this.logger.log(`✅ Started producing demo events every ${interval}ms`);
    } catch (e) {
      this.logger.error('Critical error in startProducing', e);
      this.isProducing = false;
    }
  }

  stopProducing(): void {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = undefined;
      this.logger.log('⏸️  Stopped producing demo events');
    }
  }

  private generateDemoEvent(): DemoEvent {
    const types: DemoEvent['type'][] = ['order', 'payment', 'shipment', 'notification'];
    const randomType = types[Math.floor(Math.random() * types.length)];
    
    const event: DemoEvent = {
      id: `evt-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      type: randomType,
      userId: `user-${Math.floor(Math.random() * 1000)}`,
      timestamp: new Date().toISOString(),
      data: this.generateEventData(randomType),
    };

    return event;
  }

  private generateEventData(type: DemoEvent['type']): any {
    switch (type) {
      case 'order':
        return {
          orderId: `order-${Math.floor(Math.random() * 10000)}`,
          amount: Math.floor(Math.random() * 1000) + 10,
          items: Math.floor(Math.random() * 5) + 1,
          status: 'pending',
        };
      
      case 'payment':
        return {
          paymentId: `pay-${Math.floor(Math.random() * 10000)}`,
          method: ['credit_card', 'paypal', 'bank_transfer'][Math.floor(Math.random() * 3)],
          amount: Math.floor(Math.random() * 1000) + 10,
          currency: 'USD',
        };
      
      case 'shipment':
        return {
          shipmentId: `ship-${Math.floor(Math.random() * 10000)}`,
          carrier: ['UPS', 'FedEx', 'DHL'][Math.floor(Math.random() * 3)],
          trackingNumber: `TRK${Math.random().toString(36).substr(2, 12).toUpperCase()}`,
          estimatedDelivery: new Date(Date.now() + Math.random() * 7 * 24 * 60 * 60 * 1000).toISOString(),
        };
      
      case 'notification':
        return {
          notificationId: `notif-${Math.floor(Math.random() * 10000)}`,
          channel: ['email', 'sms', 'push'][Math.floor(Math.random() * 3)],
          message: 'Your order has been updated',
          priority: ['low', 'medium', 'high'][Math.floor(Math.random() * 3)],
        };
      
      default:
        return {};
    }
  }

  async produceCustomMessage(message: any): Promise<void> {
    try {
      this.logger.log(`Sending custom message: ${JSON.stringify(message)}`);
      await this.producerService.sendBatch('demo-events', [{ value: message }]);
      this.logger.log('✅ Custom message sent successfully');
    } catch (error) {
      this.logger.error('Failed to produce custom message', error);
      throw error; // Re-throw to let controller handle it, but logged first. 
      // Actually, if we re-throw, the controller should handle it. 
      // But if it crashes the process, maybe it's an uncaught exception type?
      // NestJS Exception Filters usually handle throws.
    }
  }

  async seekConsumer(consumerId: string, offset: string) {
      // Static mapping for the demo:
      // Consumer-1 -> Partition 0
      // Consumer-2 -> Partition 1
      // Consumer-3 -> Partition 2
      let partition = 0;
      if (consumerId === 'Consumer-2') partition = 1;
      if (consumerId === 'Consumer-3') partition = 2;

      await this.consumerService.seek(consumerId, {
          topic: 'demo-events',
          partition,
          offset,
      });
  }

  getStatistics() {
    return {
      totalMessagesProduced: this.messageCount,
      isProducing: !!this.intervalId,
      partitionWeights: this.partitionWeights,
    };
  }

  updateConfig(config: { partitionWeights: number[] }) {
    if (config.partitionWeights && config.partitionWeights.length === 3) {
      this.partitionWeights = config.partitionWeights;
      this.logger.log(`Updated partition weights: ${this.partitionWeights.join(', ')}`);
    }
  }

  private getTargetPartition(): number {
    const totalWeight = this.partitionWeights.reduce((a, b) => a + b, 0);
    if (totalWeight === 0) return 0; // Prevent division by zero, default to 0

    let random = Math.random() * totalWeight;
    
    for (let i = 0; i < this.partitionWeights.length; i++) {
      random -= this.partitionWeights[i];
      if (random < 0) return i;
    }
    return 0; // Fallback
  }
}
