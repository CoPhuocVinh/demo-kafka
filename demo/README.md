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
- ✅ **Laser beam animation** hiệu ứng tia laser khi message di chuyển qua các partitions
- ✅ **Partition targeting** - gửi message tới partition cụ thể hoặc tự động
- ✅ **Weighted distribution** - điều chỉnh tỷ lệ phân phối message theo partition
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
cd kafka-demo/demo

# Copy environment variables (review và điều chỉnh nếu cần)
cp .env.example .env

# Start all services
docker compose up -d

# Hoặc sử dụng helper script
./scripts/dev.sh start

# View logs
docker compose logs -f
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

### Scenario 1: Xem Real-time Message Flow với Laser Effect

1. Mở **React Frontend**: http://localhost:8080
2. Click **"Start Data Feed"** để bắt đầu gửi messages
3. Quan sát **hiệu ứng tia laser** di chuyển:
   - 🟠 **Producer → Partition**: Tia laser màu amber
   - 🔵 **Partition 0 → Consumer 1**: Tia laser màu cyan
   - 🟡 **Partition 1 → Consumer 2**: Tia laser màu amber  
   - 🩷 **Partition 2 → Consumer 3**: Tia laser màu pink
4. Xem **Message Stream** phía dưới hiển thị chi tiết từng message theo Consumer

### Scenario 2: Điều Chỉnh Partition Distribution

1. Trong **Control Center**, tìm phần **"Partition Distribution"**
2. Sử dụng sliders để điều chỉnh tỷ lệ messages gửi vào mỗi partition:
   - **P0**: Slider cho Partition 0
   - **P1**: Slider cho Partition 1
   - **P2**: Slider cho Partition 2
3. Ví dụ: Set P0=5, P1=3, P2=2 → 50% messages vào P0, 30% vào P1, 20% vào P2

### Scenario 3: Manual Event Injection với Partition Targeting

1. Trong **Control Center**, tìm phần **"Manual Event Injection"**
2. Chọn partition đích:
   - **Auto**: Gửi theo weighted distribution (theo sliders)
   - **P0/P1/P2**: Gửi trực tiếp tới partition cụ thể
3. Nhập message JSON và click Send
4. Quan sát tia laser di chuyển tới đúng partition đã chọn

```bash
# Via REST API - Auto partition
curl -X POST http://localhost:3000/demo/send \
  -H "Content-Type: application/json" \
  -d '{"type": "custom", "message": "Hello Kafka!"}'

# Via REST API - Specific partition
curl -X POST http://localhost:3000/demo/send \
  -H "Content-Type: application/json" \
  -d '{"type": "custom", "message": "To Partition 1!", "partition": 1}'

# Start/stop auto-producer
curl -X POST http://localhost:3000/demo/stop
curl -X POST http://localhost:3000/demo/start
```

### Scenario 4: Consumer Offset Seek (Replay Messages)

1. Click vào bất kỳ **Consumer node** trong Visualizer
2. Popup hiện ra với thông tin:
   - Current Offset
   - Latest Offset (High Watermark)
   - Consumer Lag
3. Nhập offset mới và click **Seek** để replay messages
4. Hoặc click **Reset** để quay về offset 0

### Scenario 5: Monitor với Grafana

1. Truy cập **Grafana**: http://localhost:3001 (admin/admin)
2. Navigate Dashboard folder "Kafka"
3. Xem các metrics:
   - Message Throughput
   - Consumer Lag per partition
   - WebSocket connections
   - Application Metrics

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

## 🌐 VPS Deployment (Ubuntu 22.04/24.04)

### Automated Setup

```bash
# SSH to VPS
ssh user@your-vps-ip

# Clone project
git clone YOUR_REPO kafka-demo
cd kafka-demo/demo

# Run setup script (installs Docker, configures system, firewall)
./scripts/setup-vps.sh

# Or with auto-deploy
REPO_URL=YOUR_REPO ./scripts/setup-vps.sh --with-deploy
```

**Script sẽ tự động:**
- ✅ Kiểm tra system requirements (RAM, disk)
- ✅ Cài đặt Docker & Docker Compose
- ✅ Cấu hình system limits cho Kafka
- ✅ Cấu hình UFW firewall
- ✅ Thêm user vào docker group

### Manual Setup

```bash
# 1. Install Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER

# 2. Configure system limits for Kafka
sudo tee -a /etc/sysctl.conf <<EOF
vm.max_map_count=262144
fs.file-max=65536
EOF
sudo sysctl -p

# 3. Clone project
git clone YOUR_REPO kafka-demo
cd kafka-demo/demo

# 4. Setup environment
cp .env.example .env
# Edit .env if needed

# 5. Start services
docker compose up -d
```

### Firewall Rules

Script tự động cấu hình, hoặc manual:

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 8080/tcp  # Frontend
sudo ufw allow 3000/tcp  # Backend
sudo ufw allow 3001/tcp  # Grafana
sudo ufw allow 8081/tcp  # Kafka UI
sudo ufw allow 9090/tcp  # Prometheus
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

## 🔧 Operations Scripts

### Development (`./scripts/dev.sh`)

```bash
./scripts/dev.sh start      # Start all services
./scripts/dev.sh stop       # Stop all services
./scripts/dev.sh restart    # Restart all services
./scripts/dev.sh logs       # Follow all logs
./scripts/dev.sh rebuild    # Rebuild backend/frontend
./scripts/dev.sh clean      # Remove all data
./scripts/dev.sh kafka      # Open Kafka CLI shell
```

### Production (`./scripts/prod.sh`)

```bash
# Service Management
./scripts/prod.sh start     # Start with health check
./scripts/prod.sh stop      # Stop with confirmation
./scripts/prod.sh restart   # Restart all services
./scripts/prod.sh status    # Status + resource usage
./scripts/prod.sh health    # Run health checks

# Logs & Monitoring
./scripts/prod.sh logs              # Follow all logs
./scripts/prod.sh logs backend      # Follow specific service
./scripts/prod.sh metrics           # Quick metrics summary

# Maintenance
./scripts/prod.sh rebuild           # Zero-downtime rebuild
./scripts/prod.sh rebuild frontend  # Rebuild specific service
./scripts/prod.sh update            # Git pull + rebuild
./scripts/prod.sh backup            # Backup data & configs
./scripts/prod.sh restore           # Restore from backup
./scripts/prod.sh clean             # Remove all data (DANGEROUS)

# Tools
./scripts/prod.sh kafka             # Open Kafka CLI shell
```

---

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
│   │   │   ├── producer.service.ts
│   │   │   └── consumer.service.ts
│   │   ├── websocket/          # Socket.io gateway
│   │   │   └── events.gateway.ts
│   │   ├── metrics/            # Prometheus metrics
│   │   │   └── metrics.service.ts
│   │   └── demo/               # Demo controller & service
│   │       ├── demo.controller.ts  # REST API endpoints
│   │       └── demo.service.ts     # Business logic, partition weights
│   ├── Dockerfile
│   └── package.json
├── frontend/                    # React application
│   ├── src/
│   │   ├── components/
│   │   │   ├── Dashboard.tsx       # Main layout
│   │   │   ├── ClusterVisualizer.tsx # React Flow với laser effects
│   │   │   ├── MessageStream.tsx   # Message log columns
│   │   │   ├── ControlPanel.tsx    # Start/Stop, Partition config, Manual send
│   │   │   └── ClusterStatus.tsx   # Metrics overview
│   │   ├── hooks/
│   │   │   └── useSocket.ts        # WebSocket connection hook
│   │   └── index.css               # Tailwind + custom animations
│   ├── Dockerfile
│   └── package.json
├── monitoring/
│   ├── prometheus/
│   │   └── prometheus.yml      # Scrape configs
│   └── grafana/
│       ├── provisioning/       # Datasources & dashboards
│       └── dashboards/         # JSON definitions
├── docs/
│   └── ARCHITECTURE.md         # Technical documentation
├── scripts/
│   ├── setup-vps.sh            # VPS deployment script
│   ├── dev.sh                  # Local development helper
│   └── prod.sh                 # Production management script
└── .env.example                # Environment variables template
```

## 🎯 Key Features

### Kafka KRaft Mode
- ✅ No Zookeeper dependency
- ✅ Simplified architecture
- ✅ Combined controller + broker nodes
- ✅ Faster metadata propagation

### Interactive UI Controls
| Control | Description |
|---------|-------------|
| **Start/Stop Data Feed** | Bật/tắt auto-producer |
| **Partition Distribution** | 3 sliders điều chỉnh tỷ lệ P0/P1/P2 |
| **Manual Event Injection** | Gửi message với partition targeting |
| **Consumer Seek** | Click Consumer node để reset offset |
| **Pause Stream** | Tạm dừng live update để đọc logs |

### Multi-Partition Demo
- 3 partitions per topic
- **Weighted distribution** - điều chỉnh tỷ lệ phân phối qua UI
- **Partition targeting** - gửi message tới partition cụ thể
- Parallel consumer processing
- Consumer group coordination

### Real-time Visualization
- WebSocket live streaming
- **Laser beam animation** - hiệu ứng tia laser với particles
- **Glowing edges** - đường kết nối phát sáng khi có message
- **Color-coded consumers** - Cyan/Amber/Pink cho từng consumer
- Partition-level metrics
- Consumer lag monitoring
- **Consumer offset seek** - replay messages từ bất kỳ offset

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
