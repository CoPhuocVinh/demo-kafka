#!/bin/bash

# ============================================
# Kafka Demo - Production Management Script
# ============================================
# Usage: ./prod.sh [command]
#
# Commands:
#   start       - Start all services
#   stop        - Stop all services (with confirmation)
#   restart     - Restart all services
#   status      - Show service status & health
#   logs        - Follow logs (all or specific service)
#   rebuild     - Rebuild and restart with zero-downtime
#   update      - Pull latest code and rebuild
#   backup      - Backup Kafka data & configs
#   restore     - Restore from backup
#   clean       - Stop and remove all data (DANGEROUS)
#   health      - Run health checks
#   kafka       - Open Kafka CLI shell
#   metrics     - Show quick metrics summary
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Backup directory
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_DIR/backups}"

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"
}

confirm() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Check if services are running
check_running() {
    if docker compose ps --quiet 2>/dev/null | grep -q .; then
        return 0
    else
        return 1
    fi
}

case "$1" in
    start)
        print_header "Starting Production Services"
        
        if check_running; then
            echo -e "${YELLOW}Services are already running.${NC}"
            docker compose ps
            exit 0
        fi
        
        echo "Starting services..."
        docker compose up -d
        
        echo ""
        echo "Waiting for services to be healthy..."
        sleep 5
        
        # Health check
        $0 health
        
        echo ""
        echo -e "${GREEN}✅ Services started successfully!${NC}"
        echo ""
        echo "Access:"
        echo -e "  Frontend:  ${CYAN}http://$(hostname -I | awk '{print $1}'):8080${NC}"
        echo -e "  Grafana:   ${CYAN}http://$(hostname -I | awk '{print $1}'):3001${NC}"
        echo -e "  Kafka UI:  ${CYAN}http://$(hostname -I | awk '{print $1}'):8081${NC}"
        ;;
    
    stop)
        print_header "Stopping Production Services"
        
        if ! check_running; then
            echo "Services are not running."
            exit 0
        fi
        
        if confirm "This will stop all services. Users will be disconnected."; then
            echo "Stopping services gracefully..."
            docker compose stop
            echo -e "${GREEN}✅ Services stopped.${NC}"
        else
            echo "Cancelled."
        fi
        ;;
    
    restart)
        print_header "Restarting Production Services"
        
        echo "Restarting services..."
        docker compose restart
        
        sleep 3
        $0 health
        
        echo -e "${GREEN}✅ Services restarted.${NC}"
        ;;
    
    status)
        print_header "Service Status"
        
        docker compose ps
        
        echo ""
        echo -e "${CYAN}Resource Usage:${NC}"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null || true
        ;;
    
    logs)
        SERVICE="${2:-}"
        
        if [ -z "$SERVICE" ]; then
            echo "Following all logs (Ctrl+C to exit)..."
            docker compose logs -f --tail=100
        else
            echo "Following $SERVICE logs (Ctrl+C to exit)..."
            docker compose logs -f --tail=100 "$SERVICE"
        fi
        ;;
    
    rebuild)
        print_header "Rebuilding Services (Zero-Downtime)"
        
        SERVICE="${2:-}"
        
        if [ -z "$SERVICE" ]; then
            # Rebuild frontend and backend only (not Kafka)
            echo "Rebuilding frontend and backend..."
            docker compose build --no-cache backend frontend
            
            echo "Updating backend (rolling)..."
            docker compose up -d --no-deps backend
            sleep 3
            
            echo "Updating frontend (rolling)..."
            docker compose up -d --no-deps frontend
            sleep 2
        else
            echo "Rebuilding $SERVICE..."
            docker compose build --no-cache "$SERVICE"
            docker compose up -d --no-deps "$SERVICE"
        fi
        
        $0 health
        echo -e "${GREEN}✅ Rebuild complete.${NC}"
        ;;
    
    update)
        print_header "Updating from Git Repository"
        
        echo "Current version:"
        git log --oneline -1 2>/dev/null || echo "Not a git repository"
        echo ""
        
        if confirm "Pull latest changes and rebuild?"; then
            echo "Pulling latest changes..."
            git pull
            
            echo ""
            echo "New version:"
            git log --oneline -1
            
            echo ""
            $0 rebuild
        else
            echo "Cancelled."
        fi
        ;;
    
    backup)
        print_header "Backing Up Data"
        
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_PATH="$BACKUP_DIR/backup_$TIMESTAMP"
        
        mkdir -p "$BACKUP_PATH"
        
        echo "Backup directory: $BACKUP_PATH"
        echo ""
        
        # Backup configs
        echo "Backing up configs..."
        cp -r "$PROJECT_DIR/.env" "$BACKUP_PATH/" 2>/dev/null || true
        cp -r "$PROJECT_DIR/docker-compose.yml" "$BACKUP_PATH/"
        cp -r "$PROJECT_DIR/monitoring" "$BACKUP_PATH/"
        
        # Backup Kafka data (volumes)
        echo "Backing up Kafka data volumes..."
        for i in 1 2 3; do
            docker run --rm \
                -v demo_kafka-${i}-data:/data \
                -v "$BACKUP_PATH":/backup \
                alpine tar czf /backup/kafka-${i}-data.tar.gz -C /data . 2>/dev/null || true
        done
        
        # Backup Grafana data
        echo "Backing up Grafana data..."
        docker run --rm \
            -v demo_grafana-data:/data \
            -v "$BACKUP_PATH":/backup \
            alpine tar czf /backup/grafana-data.tar.gz -C /data . 2>/dev/null || true
        
        # Create manifest
        echo "Creating backup manifest..."
        cat > "$BACKUP_PATH/manifest.txt" <<EOF
Kafka Demo Backup
=================
Date: $(date)
Host: $(hostname)
Git Commit: $(git rev-parse HEAD 2>/dev/null || echo "N/A")

Contents:
- .env (environment config)
- docker-compose.yml
- monitoring/ (Prometheus & Grafana configs)
- kafka-1-data.tar.gz
- kafka-2-data.tar.gz
- kafka-3-data.tar.gz
- grafana-data.tar.gz
EOF
        
        # Calculate size
        BACKUP_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
        
        echo ""
        echo -e "${GREEN}✅ Backup complete!${NC}"
        echo "   Location: $BACKUP_PATH"
        echo "   Size: $BACKUP_SIZE"
        
        # List recent backups
        echo ""
        echo "Recent backups:"
        ls -lt "$BACKUP_DIR" 2>/dev/null | head -5
        ;;
    
    restore)
        print_header "Restore from Backup"
        
        # List available backups
        echo "Available backups:"
        ls -lt "$BACKUP_DIR" 2>/dev/null | grep "backup_" | head -10
        echo ""
        
        read -p "Enter backup folder name (e.g., backup_20240122_120000): " BACKUP_NAME
        BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
        
        if [ ! -d "$BACKUP_PATH" ]; then
            echo -e "${RED}Backup not found: $BACKUP_PATH${NC}"
            exit 1
        fi
        
        if confirm "This will stop services and restore from $BACKUP_NAME. Current data will be OVERWRITTEN!"; then
            echo "Stopping services..."
            docker compose down
            
            echo "Restoring Kafka volumes..."
            for i in 1 2 3; do
                if [ -f "$BACKUP_PATH/kafka-${i}-data.tar.gz" ]; then
                    docker volume rm demo_kafka-${i}-data 2>/dev/null || true
                    docker volume create demo_kafka-${i}-data
                    docker run --rm \
                        -v demo_kafka-${i}-data:/data \
                        -v "$BACKUP_PATH":/backup \
                        alpine tar xzf /backup/kafka-${i}-data.tar.gz -C /data
                fi
            done
            
            echo "Restoring Grafana data..."
            if [ -f "$BACKUP_PATH/grafana-data.tar.gz" ]; then
                docker volume rm demo_grafana-data 2>/dev/null || true
                docker volume create demo_grafana-data
                docker run --rm \
                    -v demo_grafana-data:/data \
                    -v "$BACKUP_PATH":/backup \
                    alpine tar xzf /backup/grafana-data.tar.gz -C /data
            fi
            
            echo "Starting services..."
            docker compose up -d
            
            sleep 5
            $0 health
            
            echo -e "${GREEN}✅ Restore complete!${NC}"
        else
            echo "Cancelled."
        fi
        ;;
    
    clean)
        print_header "Clean All Data (DANGEROUS)"
        
        echo -e "${RED}╔═══════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  WARNING: This will DELETE ALL DATA!          ║${NC}"
        echo -e "${RED}║  - All Kafka messages                         ║${NC}"
        echo -e "${RED}║  - All Grafana dashboards & settings          ║${NC}"
        echo -e "${RED}║  - All Prometheus metrics history             ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════╝${NC}"
        echo ""
        
        if confirm "Type 'DELETE' to confirm:"; then
            read -p "Confirmation: " CONFIRM
            if [ "$CONFIRM" = "DELETE" ]; then
                echo "Stopping and removing all data..."
                docker compose down -v --remove-orphans
                echo -e "${GREEN}✅ All data removed.${NC}"
            else
                echo "Confirmation failed. Cancelled."
            fi
        else
            echo "Cancelled."
        fi
        ;;
    
    health)
        print_header "Health Check"
        
        ALL_HEALTHY=true
        
        # Check each service
        echo "Checking services..."
        echo ""
        
        # Kafka brokers
        for i in 1 2 3; do
            if docker exec kafka-$i /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server 127.0.0.1:9092 &>/dev/null; then
                echo -e "  Kafka Broker $i:  ${GREEN}✓ Healthy${NC}"
            else
                echo -e "  Kafka Broker $i:  ${RED}✗ Unhealthy${NC}"
                ALL_HEALTHY=false
            fi
        done
        
        # Backend
        if curl -s http://localhost:3000/metrics &>/dev/null; then
            echo -e "  Backend:         ${GREEN}✓ Healthy${NC}"
        else
            echo -e "  Backend:         ${RED}✗ Unhealthy${NC}"
            ALL_HEALTHY=false
        fi
        
        # Frontend
        if curl -s http://localhost:8080 &>/dev/null; then
            echo -e "  Frontend:        ${GREEN}✓ Healthy${NC}"
        else
            echo -e "  Frontend:        ${RED}✗ Unhealthy${NC}"
            ALL_HEALTHY=false
        fi
        
        # Grafana
        if curl -s http://localhost:3001/api/health &>/dev/null; then
            echo -e "  Grafana:         ${GREEN}✓ Healthy${NC}"
        else
            echo -e "  Grafana:         ${RED}✗ Unhealthy${NC}"
            ALL_HEALTHY=false
        fi
        
        # Prometheus
        if curl -s http://localhost:9090/-/healthy &>/dev/null; then
            echo -e "  Prometheus:      ${GREEN}✓ Healthy${NC}"
        else
            echo -e "  Prometheus:      ${RED}✗ Unhealthy${NC}"
            ALL_HEALTHY=false
        fi
        
        echo ""
        
        if [ "$ALL_HEALTHY" = true ]; then
            echo -e "${GREEN}All services are healthy!${NC}"
        else
            echo -e "${RED}Some services are unhealthy!${NC}"
            exit 1
        fi
        ;;
    
    kafka)
        print_header "Kafka CLI Shell"
        
        echo "Useful commands:"
        echo "  kafka-topics.sh --bootstrap-server localhost:9092 --list"
        echo "  kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic demo-events"
        echo "  kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list"
        echo "  kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group demo-shared-group --describe"
        echo ""
        
        docker exec -it kafka-1 /bin/bash
        ;;
    
    metrics)
        print_header "Quick Metrics Summary"
        
        echo "Fetching metrics from backend..."
        echo ""
        
        # Get stats from backend
        STATS=$(curl -s http://localhost:3000/demo/statistics 2>/dev/null || echo "{}")
        
        if [ "$STATS" != "{}" ]; then
            echo "$STATS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"  Messages Produced:  {data.get('totalMessagesProduced', 'N/A')}\")
print(f\"  Producer Active:    {'Yes' if data.get('isProducing') else 'No'}\")
weights = data.get('partitionWeights', [])
if weights:
    print(f\"  Partition Weights:  P0={weights[0]}, P1={weights[1]}, P2={weights[2]}\")
" 2>/dev/null || echo "  Unable to parse metrics"
        else
            echo "  Unable to fetch metrics from backend"
        fi
        
        echo ""
        echo "WebSocket Connections:"
        # Try to get from metrics endpoint
        WS_COUNT=$(curl -s http://localhost:3000/metrics 2>/dev/null | grep "websocket_active_connections" | grep -v "#" | awk '{print $2}' || echo "N/A")
        echo "  Active connections: $WS_COUNT"
        
        echo ""
        echo "Kafka Topics:"
        docker exec kafka-1 /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list 2>/dev/null | head -5 || echo "  Unable to list topics"
        ;;
    
    *)
        echo -e "${CYAN}Kafka Demo - Production Management${NC}"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Service Management:"
        echo "  start       Start all services"
        echo "  stop        Stop all services (with confirmation)"
        echo "  restart     Restart all services"
        echo "  status      Show service status & resource usage"
        echo "  health      Run health checks on all services"
        echo ""
        echo "Logs & Monitoring:"
        echo "  logs [svc]  Follow logs (optionally for specific service)"
        echo "  metrics     Show quick metrics summary"
        echo ""
        echo "Maintenance:"
        echo "  rebuild [svc]  Rebuild and restart (zero-downtime)"
        echo "  update         Pull latest code and rebuild"
        echo "  backup         Backup all data & configs"
        echo "  restore        Restore from backup"
        echo "  clean          Remove all data (DANGEROUS)"
        echo ""
        echo "Tools:"
        echo "  kafka       Open Kafka CLI shell"
        echo ""
        echo "Examples:"
        echo "  $0 start"
        echo "  $0 logs backend"
        echo "  $0 rebuild frontend"
        echo "  $0 backup"
        ;;
esac
