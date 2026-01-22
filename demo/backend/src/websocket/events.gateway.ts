import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { MetricsService } from '../metrics/metrics.service';

@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class EventsGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(EventsGateway.name);
  private connectedClients = 0;

  constructor(private readonly metricsService: MetricsService) {}

  afterInit(server: Server) {
    this.logger.log('🔌 WebSocket Gateway initialized');
  }

  handleConnection(client: Socket) {
    this.connectedClients++;
    this.logger.log(`Client connected: ${client.id} (Total: ${this.connectedClients})`);
    
    // Update metrics
    this.metricsService.setActiveWebSocketConnections(this.connectedClients);

    // Send welcome message
    client.emit('connection-status', {
      status: 'connected',
      timestamp: new Date().toISOString(),
      totalClients: this.connectedClients,
    });

    // Broadcast client count to all clients
    this.server.emit('clients-update', { 
      totalClients: this.connectedClients 
    });
  }

  handleDisconnect(client: Socket) {
    this.connectedClients--;
    this.logger.log(`Client disconnected: ${client.id} (Total: ${this.connectedClients})`);
    
    // Update metrics
    this.metricsService.setActiveWebSocketConnections(this.connectedClients);
    
    this.server.emit('clients-update', { 
      totalClients: this.connectedClients 
    });
  }

  @SubscribeMessage('ping')
  handlePing(client: Socket): void {
    client.emit('pong', { timestamp: new Date().toISOString() });
  }

  // Broadcast Kafka messages to all connected clients
  broadcastMessage(message: any): void {
    const payload = {
      ...message,
      receivedAt: new Date().toISOString(),
    };
    this.logger.log(`Broadcast kafka-message: ${JSON.stringify(payload)}`);
    this.server.emit('kafka-message', payload);
  }

  // Broadcast cluster status
  broadcastClusterStatus(status: any): void {
    this.server.emit('cluster-status', status);
  }

  // Broadcast metrics
  broadcastMetrics(metrics: any): void {
    this.server.emit('metrics-update', metrics);
  }

  // Get number of connected clients
  getConnectedClients(): number {
    return this.connectedClients;
  }
}
