#!/bin/bash

# ============================================
# Kafka Demo - Local Development Script
# ============================================
# Quick commands for local development
# Usage: ./dev.sh [command]
#
# Commands:
#   start     - Start all services
#   stop      - Stop all services
#   restart   - Restart all services
#   logs      - Follow logs
#   status    - Show service status
#   rebuild   - Rebuild and restart backend/frontend
#   clean     - Stop and remove all data
#   kafka     - Open Kafka CLI shell
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

case "$1" in
    start)
        echo -e "${BLUE}Starting all services...${NC}"
        docker compose up -d
        echo -e "${GREEN}✅ Services started!${NC}"
        echo ""
        echo "Access:"
        echo "  Frontend:  http://localhost:8080"
        echo "  Grafana:   http://localhost:3001 (admin/admin)"
        echo "  Kafka UI:  http://localhost:8081"
        ;;
    
    stop)
        echo -e "${BLUE}Stopping all services...${NC}"
        docker compose down
        echo -e "${GREEN}✅ Services stopped!${NC}"
        ;;
    
    restart)
        echo -e "${BLUE}Restarting all services...${NC}"
        docker compose restart
        echo -e "${GREEN}✅ Services restarted!${NC}"
        ;;
    
    logs)
        docker compose logs -f
        ;;
    
    status)
        docker compose ps
        ;;
    
    rebuild)
        echo -e "${BLUE}Rebuilding backend and frontend...${NC}"
        docker compose build backend frontend
        docker compose up -d backend frontend
        echo -e "${GREEN}✅ Rebuild complete!${NC}"
        ;;
    
    clean)
        echo -e "${YELLOW}⚠️  This will stop all services and DELETE ALL DATA!${NC}"
        read -p "Are you sure? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker compose down -v
            echo -e "${GREEN}✅ All services stopped and data removed!${NC}"
        else
            echo "Cancelled."
        fi
        ;;
    
    kafka)
        echo -e "${BLUE}Opening Kafka CLI shell...${NC}"
        echo "Available commands:"
        echo "  kafka-topics.sh --bootstrap-server localhost:9092 --list"
        echo "  kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list"
        echo ""
        docker exec -it kafka-1 /bin/bash
        ;;
    
    *)
        echo "Kafka Demo - Development Helper"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  start     Start all services"
        echo "  stop      Stop all services"
        echo "  restart   Restart all services"
        echo "  logs      Follow service logs"
        echo "  status    Show service status"
        echo "  rebuild   Rebuild backend/frontend and restart"
        echo "  clean     Stop services and remove all data"
        echo "  kafka     Open Kafka CLI shell"
        ;;
esac
