# Kiến Thức Bổ Sung về Apache Kafka

## 1. Replication & High Availability

### Leader & Follower Replicas

Kafka đảm bảo **data durability** thông qua cơ chế replication:

- **Leader Replica**: Partition chính xử lý mọi read/write requests
- **Follower Replicas**: Các bản sao đồng bộ data từ Leader
- **Replication Factor**: Số lượng replicas của mỗi partition (thường là 3)

```
Topic: orders, Partition: 0, Replication Factor: 3
├── Leader: Broker 1 (handles all I/O)
├── Follower: Broker 2 (syncs from Leader)
└── Follower: Broker 3 (syncs from Leader)
```

### In-Sync Replicas (ISR)

**ISR** là tập hợp các replicas đang đồng bộ tốt với Leader:

- Chỉ các ISR mới được tính là "an toàn"
- Nếu Follower lag quá xa → bị loại khỏi ISR
- **min.insync.replicas**: Số ISR tối thiểu để chấp nhận write (thường = 2)

```
acks=all → Producer chờ tất cả ISR acknowledge
acks=1   → Chỉ chờ Leader acknowledge (nhanh nhưng rủi ro hơn)
acks=0   → Không chờ (fastest, least safe)
```

### Failover Mechanism

Khi Leader partition chết:

1. **Controller** (một Broker được bầu làm coordinator) phát hiện
2. Chọn một Follower từ ISR làm Leader mới
3. Các Producer/Consumer tự động reconnect đến Leader mới
4. **Không mất data** nếu min.insync.replicas được tuân thủ

---

## 2. Offset Management Chi Tiết

### Offset Là Gì?

**Offset** = vị trí (ID) của message trong partition:

- Bắt đầu từ 0, tăng dần khi có message mới
- Mỗi Consumer Group lưu offset riêng cho từng partition
- Offset được commit vào internal topic `__consumer_offsets`

### Commit Strategies

#### Auto-commit (Default)
```java
enable.auto.commit=true
auto.commit.interval.ms=5000  // Commit mỗi 5s
```

**Ưu điểm**: Đơn giản, không cần code thêm  
**Nhược điểm**: Có thể **mất message** hoặc **duplicate** khi crash giữa 2 lần commit

#### Manual Commit
```java
enable.auto.commit=false

// Synchronous commit (block cho đến khi thành công)
consumer.commitSync();

// Asynchronous commit (không block)
consumer.commitAsync();
```

**Best practice**: 
- Commit **sau khi** xử lý xong message
- Dùng `commitSync()` khi shutdown để đảm bảo offset được lưu

### Offset Reset

Khi Consumer Group mới hoặc offset không tồn tại:

```properties
auto.offset.reset=earliest  # Đọc từ đầu topic
auto.offset.reset=latest    # Đọc từ message mới nhất (default)
auto.offset.reset=none      # Throw exception nếu không có offset
```

### Seek Operations (Replay Data)

```java
// Jump đến offset cụ thể
consumer.seek(partition, 12345);

// Về đầu partition
consumer.seekToBeginning(partitions);

// Đến cuối partition
consumer.seekToEnd(partitions);
```

**Use case**: Replay data khi cần xử lý lại, hoặc skip bad messages

---

## 3. Performance & Tuning

### Batch Processing

**Producer-side batching**:
```properties
batch.size=16384           # Batch tối đa 16KB trước khi send
linger.ms=10               # Chờ tối đa 10ms để tích lũy messages
```

**Nguyên tắc**: Tăng batch size → giảm số lần network calls → tăng throughput

### Compression

```properties
compression.type=snappy    # Các lựa chọn: none, gzip, snappy, lz4, zstd
```

| Compression | CPU Usage | Ratio | Tốc độ |
|-------------|-----------|-------|--------|
| **snappy** | Thấp | Trung bình | Nhanh nhất ✅ |
| **lz4** | Thấp | Trung bình | Rất nhanh |
| **gzip** | Cao | Tốt nhất | Chậm |
| **zstd** | Trung bình | Tốt | Cân bằng |

**Khuyến nghị**: Dùng `snappy` hoặc `lz4` cho production

### Page Cache & Zero-Copy

Kafka tận dụng **OS page cache**:

- Messages được write vào page cache (RAM) trước khi flush disk
- Consumers đọc từ page cache → cực nhanh nếu cache hit
- **Zero-copy**: Dùng `sendfile()` system call → transfer data trực tiếp từ disk → network socket, không qua application memory

**Kết quả**: Kafka có thể handle **hàng triệu messages/sec** trên 1 broker

### Partition Count

**Nguyên tắc vàng**:
- Nhiều partitions = parallel processing cao hơn
- **NHƯNG**: Quá nhiều partitions → overhead trong:
  - Leader election time
  - Memory usage (mỗi partition = file handles)
  
**Khuyến nghị**: 
- Start với `số brokers × 2 hoặc × 3`
- Max ~4000 partitions/broker (tùy hardware)

---

## 4. Message Delivery Guarantees

### At-Most-Once (Có thể mất message)

```
Producer: acks=0 (fire and forget)
Consumer: auto-commit TRƯỚC khi xử lý
```

→ **Nhanh nhất** nhưng có thể **mất data** khi crash

### At-Least-Once (Có thể duplicate)

```
Producer: acks=all + retries
Consumer: commitSync() SAU khi xử lý
```

→ **An toàn hơn** nhưng có thể **duplicate** nếu commit fail sau khi xử lý

### Exactly-Once Semantics (EOS) ✅

Kết hợp 2 cơ chế:

#### 1. Idempotent Producer
```properties
enable.idempotence=true  # Tự động set acks=all, retries=MAX
```

- Kafka gán **Producer ID** + **Sequence Number** cho mỗi message
- Broker detect và reject duplicates

#### 2. Transactions
```java
producer.initTransactions();
producer.beginTransaction();
producer.send(record1);
producer.send(record2);
producer.commitTransaction();  // Atomically commit hoặc rollback
```

**Use case**: Kafka Streams, hoặc bất kỳ flow nào cần **exactly-once**

---

## 5. Use Cases & Anti-patterns

### ✅ Khi NÊN Dùng Kafka

| Use Case | Lý do |
|----------|-------|
| **Event Sourcing** | Lưu trữ vĩnh viễn, replay được |
| **Log Aggregation** | Centralized logging từ nhiều services |
| **Stream Processing** | Real-time analytics, transformations |
| **CDC (Change Data Capture)** | Track DB changes qua Debezium Connector |
| **Metrics Collection** | High throughput, có thể chịu latency vài ms |

### ❌ Khi KHÔNG NÊN Dùng

| Anti-pattern | Lý do | Dùng gì thay thế |
|--------------|-------|------------------|
| **Request-Reply** | Kafka không hỗ trợ correlation ID tốt | RabbitMQ, gRPC |
| **Low latency \u003c 1ms** | Batch processing tạo độ trễ | Redis Streams, NATS |
| **Small messages** | Overhead lớn với messages \u003c 1KB | Redis Pub/Sub |
| **Guaranteed ordering qua partitions** | Kafka chỉ đảm bảo order TRONG partition | Single partition (giảm throughput) |

### So Sánh Kafka vs RabbitMQ

| Tiêu chí | Kafka | RabbitMQ |
|----------|-------|----------|
| **Throughput** | Rất cao (hàng triệu msg/s) | Vừa phải |
| **Latency** | 5-15ms | 1-5ms |
| **Retention** | Dài hạn (days/weeks) | Ngắn (xóa sau khi consume) |
| **Ordering** | Trong partition | Trong queue |
| **Use case** | Event streaming, analytics | Task queues, RPC |

---

## 6. Operations & Monitoring

### Key Metrics

#### Broker Metrics
```
kafka.server:type=BrokerTopicMetrics,name=MessagesInPerSec
kafka.server:type=BrokerTopicMetrics,name=BytesInPerSec
kafka.network:type=RequestMetrics,name=TotalTimeMs,request=Produce
```

#### Consumer Lag (Quan trọng nhất!)
```bash
kafka-consumer-groups.sh --describe --group my-group

# Output:
TOPIC     PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG
orders    0          1000            1500            500  ← Lag = 500 messages
```

**Lag** = Log-End-Offset - Current-Offset  
→ Nếu lag tăng liên tục = Consumer không kịp xử lý

#### Under-Replicated Partitions
```
kafka.server:type=ReplicaManager,name=UnderReplicatedPartitions
```

→ **Cảnh báo nghiêm trọng**: Có partitions mất replicas → nguy cơ mất data

### Monitoring Tools

| Tool | Mô tả |
|------|-------|
| **Prometheus + Grafana** | Export JMX metrics → visualization |
| **Confluent Control Center** | UI toàn diện (commercial) |
| **Kafka Manager (CMAK)** | Open-source, quản lý topics/partitions |
| **Burrow** | LinkedIn's lag monitoring tool |

### Common Issues

#### 1. Under-Replicated Partitions
**Nguyên nhân**: 
- Broker chậm (disk I/O, CPU)
- Network issues
- Replication không kịp

**Fix**: 
- Tăng `replica.lag.time.max.ms`
- Scale thêm brokers
- Kiểm tra disk health

#### 2. Consumer Lag Tăng
**Nguyên nhân**:
- Consumer xử lý chậm
- Throughput tăng đột biến
- Partition count không đủ

**Fix**:
- Scale consumers (thêm instances)
- Tăng số partitions (rebalance)
- Optimize consumer logic

#### 3. Disk Full
**Nguyên nhân**: Retention quá dài

**Fix**:
```properties
log.retention.hours=168        # Giữ 7 days
log.retention.bytes=1073741824 # Max 1GB/partition
```

---

## 7. Kafka Ecosystem

### Kafka Streams

**Stream processing framework** được tích hợp sẵn:

```java
StreamsBuilder builder = new StreamsBuilder();
KStream\u003cString, String\u003e source = builder.stream("input-topic");

source
    .filter((key, value) -\u003e value.contains("important"))
    .mapValues(value -\u003e value.toUpperCase())
    .to("output-topic");

KafkaStreams streams = new KafkaStreams(builder.build(), config);
streams.start();
```

**Features**:
- **Stateful processing**: Joins, aggregations, windowing
- **Exactly-once semantics**
- **Auto-scaling**: Deploy nhiều instances → tự động chia việc

### Kafka Connect

**ETL framework** để tích hợp Kafka với external systems:

```json
{
  "name": "mysql-source-connector",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "database.hostname": "mysql",
    "database.port": "3306",
    "database.user": "kafka",
    "database.password": "kafka",
    "database.server.id": "1",
    "database.server.name": "mysql",
    "table.include.list": "mydb.users",
    "database.history.kafka.topic": "schema-changes"
  }
}
```

**Connectors phổ biến**:
- **Source**: MySQL (Debezium), PostgreSQL, MongoDB, JDBC, S3
- **Sink**: Elasticsearch, JDBC, S3, BigQuery, Cassandra

### Schema Registry

Quản lý **schema evolution** cho messages:

```java
// Producer gửi Avro message
GenericRecord user = new GenericData.Record(schema);
user.put("name", "Alice");
user.put("age", 30);

producer.send(new ProducerRecord\u003c\u003e("users", user));
```

**Schema Registry** đảm bảo:
- **Backward compatibility**: Consumer cũ đọc được message mới
- **Forward compatibility**: Consumer mới đọc được message cũ
- **Centralized schema management**

---

## Tổng Kết

### Câu Hỏi Thường Gặp

**Q: Kafka có thay thế được Database không?**  
A: **Không**. Kafka là event log, không phải data store. Dùng Kafka + DB (event sourcing pattern).

**Q: Partition count tối ưu là bao nhiêu?**  
A: Bắt đầu với `số brokers × 2-3`. Scale dần theo bottleneck (CPU, I/O).

**Q: Làm sao đảm bảo ordering qua nhiều partitions?**  
A: **Không thể**. Nếu cần strict ordering → dùng 1 partition (trade-off throughput).

**Q: Kafka có hỗ trợ priority queue không?**  
A: **Không native**. Workaround: Tạo topics riêng cho mỗi priority level.

### Next Steps

1. **Thực hành**: Setup Kafka cluster local (Docker Compose)
2. **Code**: Viết Producer/Consumer đơn giản
3. **Monitor**: Setup Prometheus + Grafana
4. **Explore**: Thử Kafka Streams với windowing/joins

### Tài Liệu Tham Khảo

- [Confluent Documentation](https://docs.confluent.io/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Kafka: The Definitive Guide (Book)](https://www.confluent.io/resources/kafka-the-definitive-guide/)
