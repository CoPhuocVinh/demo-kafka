import { Controller, Get, Post, Body } from '@nestjs/common';
import { DemoService } from './demo.service';

@Controller('demo')
export class DemoController {
  constructor(private readonly demoService: DemoService) {}

  @Get('statistics')
  getStatistics() {
    return this.demoService.getStatistics();
  }

  @Post('start')
  startProducing() {
    this.demoService.startProducing();
    return { status: 'started' };
  }

  @Post('stop')
  stopProducing() {
    this.demoService.stopProducing();
    return { status: 'stopped' };
  }

  @Post('config')
  updateConfig(@Body() config: { partitionWeights: number[] }) {
    this.demoService.updateConfig(config);
    return { status: 'updated', config };
  }

  @Post('send')
  async sendCustomMessage(@Body() message: any) {
    await this.demoService.produceCustomMessage(message);
    return { status: 'sent', message };
  }

  @Post('seek')
  async seekConsumer(@Body() body: { consumerId: string; offset: string }) {
    await this.demoService.seekConsumer(body.consumerId, body.offset);
    return { status: 'seeking', consumerId: body.consumerId, offset: body.offset };
  }
}
