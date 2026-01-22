# Kafka Multi-Broker Demo - Real-time Data Flow Visualization

🚀 **Full-stack Apache Kafka demo** với 3-broker cluster (KRaft mode), NestJS backend, React real-time UI, và Prometheus + Grafana monitoring.

![Kafka Architecture](https://img.shields.io/badge/Kafka-Multi--Broker-orange?logo=apache-kafka)
![NestJS](https://img.shields.io/badge/Backend-NestJS-E0234E?logo=nestjs)
![React](https://img.shields.io/badge/Frontend-React-61DAFB?logo=react)
![Docker](https://img.shields.io/badge/Deploy-Docker%20Compose-2496ED?logo=docker)

## 📋 Tổng Quan

Demo này minh họa:
- ✅ **Multi-broker Kafka cluster** (3 brokers) với KRaft - không cần Zookeeper
- ✅ **3 partitions per topic** để demonstrate parallel processing
- ✅ **Multiple consumer groups** consuming cùng lúc
- ✅ **Real-time UI** với Socket.io để visualize data flow
- ✅ **Prometheus + Grafana** monitoring với custom dashboards
- ✅ **Auto-deployment** với Docker Compose

## 🏗️ Kiến Trúc

> 📘 **Chi tiết kỹ thuật**: Xem tài liệu đầy đủ tại [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

```
┌─────────────────────────────────────────────────────────────┐
│                     React Frontend (Port 8080)              │
│                 Real-time Data Visualization                │
└──────────────────────┬──────────────────────────────────────┘
                       │ Socket.io
┌──────────────────────▼──────────────────────────────────────┐
│               NestJS Backend (Port 3000)                    │
│    Producer │ 2x Consumer Groups │ WebSocket Gateway       │
└─────┬────────────────────┬────────────────────────────────┬─┘
      │                    │                                │
      │                    │                        ┌───────▼──────┐
      │                    │                        │  Prometheus  │
      │                    │                        │  (Port 9090) │
      │                    │                        └───────┬──────┘
      │                    │                                │
┌─────▼────────────────────▼──────────────────┐    ┌───────▼──────┐
│          Kafka Cluster (KRaft Mode)         │    │   Grafana    │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐    │    │ (Port 3001)  │
│  │ Broker1 │  │ Broker2 │  │ Broker3 │    │    └──────────────┘
│  │ :9092   │  │ :9093   │  │ :9094   │    │
│  └─────────┘  └─────────┘  └─────────┘    │
│        Topic: demo-events (3 partitions)   │
└────────────────────────────────────────────┘
         │
┌────────▼────────┐
│    Kafka UI     │
│   (Port 8081)   │
└─────────────────┘
```

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- 8GB+ RAM (recommended: 16GB+)
- Ports available: 3000, 3001, 8080, 8081, 9090-9094

### 1. Clone và Start Services

```bash
cd /home/vinhcp/Workspace/test/kafka/demo

# Copy environment variables
cp .env.example .env

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f
```

### 2. Access các Services

| Service | URL | Credentials |
|---------|-----|-------------|
| **React Frontend** | http://localhost:8080 | N/A |
| **NestJS Backend** | http://localhost:3000 | N/A |
| **Kafka UI** | http://localhost:8081 | N/A |
| **Prometheus** | http://localhost:9090 | N/A |
| **Grafana** | http://localhost:3001 | admin / admin |
| **Metrics Endpoint** | http://localhost:3000/metrics | N/A |

### 3. Verify Kafka Cluster

```bash
# Check broker status
docker exec kafka-1 kafka-broker-api-versions.sh --bootstrap-server localhost:9092

# List topics
docker exec kafka-1 kafka-topics.sh --bootstrap-server localhost:9092 --list

# View consumer groups
docker exec kafka-1 kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list
```

## 📊 Demo Scenarios

### Scenario 1: Xem Real-time Message Flow

1. Mở **React Frontend**: http://localhost:8080
2. Messages tự động được produce mỗi 2 giây
3. Quan sát data flow qua các partitions
4. Xem 2 consumer groups process parallel

### Scenario 2: Monitor với Grafana

1. Truy cập **Grafana**: http://localhost:3001 (admin/admin)
2. Navigate Dashboard folder "Kafka"
3. Xem 4 dashboards:
   - Kafka Cluster Overview
   - Message Throughput
   - Consumer Lag
   - Application Metrics

### Scenario 3: Produce Custom Messages

```bash
# Via REST API
curl -X POST http://localhost:3000/demo/send \
  -H "Content-Type: application/json" \
  -d '{"type": "custom", "data": "Hello Kafka!"}'

# Start/stop auto-producer
curl -X POST http://localhost:3000/demo/stop
curl -X POST http://localhost:3000/demo/start
```

## 🔧 Configuration

### Environment Variables

Xem file `.env.example` để configure:

```bash
# Kafka Configuration
KAFKA_NUM_PARTITIONS=3
KAFKA_REPLICATION_FACTOR=3
KAFKA_MIN_INSYNC_REPLICAS=2

# Demo Producer
DEMO_PRODUCER_INTERVAL_MS=2000
DEMO_MESSAGE_BATCH_SIZE=10
```

### Scaling Consumers

Để add thêm consumer groups, edit `backend/src/kafka/consumer.service.ts`:

```typescript
await this.startConsumer({
  topic: 'demo-events',
  groupId: 'demo-consumer-group-3', // New group
  onMessage: async (payload) => {
    // Handle message
  },
});
```

## 🌐 VPS Deployment (Ubuntu 24.04)

### Automated Setup

```bash
# SSH to VPS
ssh user@your-vps-ip

# Download setup script
wget https://raw.githubusercontent.com/YOUR_REPO/scripts/setup-vps.sh

# Make executable
chmod +x setup-vps.sh

# Run setup
./setup-vps.sh
```

### Manual Setup

```bash
# 1. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 2. Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 3. Configure system limits for Kafka
sudo tee -a /etc/sysctl.conf <<EOF
vm.max_map_count=262144
fs.file-max=65536
EOF
sudo sysctl -p

# 4. Clone project
git clone YOUR_REPO kafka-demo
cd kafka-demo/demo

# 5. Start services
docker-compose up -d
```

### Firewall Rules

```bash
# Allow necessary ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 3000/tcp  # Backend
sudo ufw allow 3001/tcp  # Grafana
sudo ufw allow 8080/tcp  # Frontend
sudo ufw allow 8081/tcp  # Kafka UI
sudo ufw enable
```

## 📈 Monitoring & Metrics

### Prometheus Metrics

Backend exposes custom metrics tại `/metrics`:

```
# Kafka metrics
kafka_messages_produced_total{topic="demo-events"}
kafka_messages_consumed_total{topic="demo-events",consumer_group="demo-consumer-group-1"}
kafka_consumer_lag{topic="demo-events",partition="0",consumer_group="demo-consumer-group-1"}

# WebSocket metrics
websocket_active_connections
```

### Grafana Dashboards

4 pre-configured dashboards:

1. **Kafka Cluster Overview**: Broker status, topics, partitions
2. **Message Throughput**: Messages/sec, bytes/sec per topic
3. **Consumer Lag**: Lag monitoring cho từng partition
4. **Application Metrics**: Backend performance, WebSocket connections

## 🧪 Development

### Local Development (without Docker)

```bash
# Terminal 1: Start Kafka cluster
docker-compose up kafka-1 kafka-2 kafka-3

# Terminal 2: Start backend
cd backend
npm install
npm run start:dev

# Terminal 3: Start frontend
cd frontend
npm install
npm run dev
```

## 🛠️ Troubleshooting

### Kafka brokers không start

```bash
# Check logs
docker-compose logs kafka-1

# Verify cluster ID matches across all brokers
docker exec kafka-1 cat /var/lib/kafka/data/meta.properties
```

### Consumer lag cao

```bash
# Check consumer group status
docker exec kafka-1 kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --group demo-consumer-group-1 \
  --describe
```

### Memory issues

```bash
# Check Docker stats
docker stats

# Reduce Kafka heap size in docker-compose.yml:
KAFKA_HEAP_OPTS: "-Xms512M -Xmx1G"
```

## 📝 Project Structure

```
demo/
├── docker-compose.yml           # Main orchestration
├── .env.example                 # Environment template
├── backend/                     # NestJS application
│   ├── src/
│   │   ├── kafka/              # Producer & Consumer services
│   │   ├── websocket/          # Socket.io gateway
│   │   ├── metrics/            # Prometheus metrics
│   │   └── demo/               # Demo event generator
│   ├── Dockerfile
│   └── package.json
├── frontend/                    # React application
│   ├── src/
│   │   ├── components/         # React components
│   │   ├── hooks/              # Custom hooks (useSocket)
│   │   └── services/           # API services
│   ├── Dockerfile
│   └── package.json
├── monitoring/
│   ├── prometheus/
│   │   └── prometheus.yml      # Scrape configs
│   └── grafana/
│       ├── provisioning/       # Datasources & dashboards
│       └── dashboards/         # JSON definitions
└── scripts/
    └── setup-vps.sh            # VPS deployment script
```

## 🎯 Key Features

### Kafka KRaft Mode
- ✅ No Zookeeper dependency
- ✅ Simplified architecture
- ✅ Combined controller + broker nodes
- ✅ Faster metadata propagation

### Multi-Partition Demo
- 3 partitions per topic
- Round-robin distribution
- Parallel consumer processing
- Consumer group coordination

### Real-time Visualization
- WebSocket live streaming
- Message flow animation
- Partition-level metrics
- Consumer lag monitoring

## 📚 References

- [Apache Kafka KRaft](https://kafka.apache.org/documentation/#kraft)
- [NestJS Microservices](https://docs.nestjs.com/microservices/kafka)
- [Socket.io Documentation](https://socket.io/docs/v4/)
- [Prometheus Metrics](https://prometheus.io/docs/introduction/overview/)

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

MIT License - see LICENSE file for details

---

**Built with ❤️ for Kafka learning and demonstration**
