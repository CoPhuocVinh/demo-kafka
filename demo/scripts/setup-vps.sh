#!/bin/bash

# ============================================
# Kafka Demo - VPS Setup Script
# ============================================
# Supports: Ubuntu 22.04 / 24.04 LTS
# Usage: ./setup-vps.sh [options]
#
# Options:
#   --check          Only check what will be done (dry-run)
#   --with-deploy    Also clone and start the application
#   --yes, -y        Skip confirmation prompts
#   --help, -h       Show this help message
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="${PROJECT_DIR:-$HOME/kafka-demo}"
REPO_URL="${REPO_URL:-}"  # Set your repo URL here or pass via env

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. It's recommended to run as a regular user with sudo privileges."
    fi
}

# Check system requirements
check_requirements() {
    print_header "Checking System Requirements"
    
    # Check OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "OS: $NAME $VERSION"
        if [[ "$ID" != "ubuntu" ]]; then
            print_warning "This script is optimized for Ubuntu. Other distros may require manual adjustments."
        fi
    fi
    
    # Check RAM
    total_ram=$(free -g | awk '/^Mem:/{print $2}')
    echo "RAM: ${total_ram}GB"
    if [ "$total_ram" -lt 4 ]; then
        print_warning "Minimum 4GB RAM recommended. You have ${total_ram}GB."
        print_warning "Kafka cluster may not start properly with low memory."
    elif [ "$total_ram" -lt 8 ]; then
        print_warning "8GB+ RAM recommended for optimal performance."
    else
        print_success "RAM is sufficient"
    fi
    
    # Check disk space
    free_disk=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    echo "Free Disk: ${free_disk}GB"
    if [ "$free_disk" -lt 10 ]; then
        print_error "At least 10GB free disk space required!"
        exit 1
    fi
    print_success "Disk space is sufficient"
}

# Pre-flight check - show what will be done
preflight_check() {
    print_header "Pre-flight Check"
    
    echo "This script will perform the following actions:"
    echo ""
    
    ACTIONS_NEEDED=0
    
    # Check Docker
    if command -v docker &> /dev/null; then
        echo -e "  [${GREEN}SKIP${NC}] Docker already installed: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    else
        echo -e "  [${YELLOW}INSTALL${NC}] Docker & Docker Compose"
        ACTIONS_NEEDED=$((ACTIONS_NEEDED + 1))
    fi
    
    # Check docker group
    if groups $USER 2>/dev/null | grep -q docker; then
        echo -e "  [${GREEN}SKIP${NC}] User already in docker group"
    else
        echo -e "  [${YELLOW}CONFIGURE${NC}] Add user to docker group"
        ACTIONS_NEEDED=$((ACTIONS_NEEDED + 1))
    fi
    
    # Check system limits
    if grep -q "vm.max_map_count=262144" /etc/sysctl.conf 2>/dev/null; then
        echo -e "  [${GREEN}SKIP${NC}] System limits already configured"
    else
        echo -e "  [${YELLOW}CONFIGURE${NC}] System limits (vm.max_map_count, fs.file-max)"
        ACTIONS_NEEDED=$((ACTIONS_NEEDED + 1))
    fi
    
    # Check UFW
    if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
        echo -e "  [${GREEN}SKIP${NC}] Firewall already active"
        # Check if our ports are configured
        if sudo ufw status | grep -q "8080"; then
            echo -e "  [${GREEN}SKIP${NC}] Firewall rules already configured"
        else
            echo -e "  [${YELLOW}CONFIGURE${NC}] Add firewall rules for app ports"
            ACTIONS_NEEDED=$((ACTIONS_NEEDED + 1))
        fi
    else
        echo -e "  [${YELLOW}CONFIGURE${NC}] Install & configure UFW firewall"
        ACTIONS_NEEDED=$((ACTIONS_NEEDED + 1))
    fi
    
    # Check deploy option
    if [ "$WITH_DEPLOY" = true ]; then
        echo ""
        echo "  Deploy actions:"
        if [ -d "$PROJECT_DIR" ]; then
            echo -e "  [${YELLOW}UPDATE${NC}] Project exists, will update"
        else
            if [ -z "$REPO_URL" ]; then
                echo -e "  [${RED}SKIP${NC}] No REPO_URL set, manual clone required"
            else
                echo -e "  [${YELLOW}CLONE${NC}] Clone repository to $PROJECT_DIR"
            fi
        fi
        echo -e "  [${YELLOW}BUILD${NC}] Build and start containers"
    fi
    
    echo ""
    
    if [ $ACTIONS_NEEDED -eq 0 ] && [ "$WITH_DEPLOY" = false ]; then
        print_success "System is already configured! Nothing to do."
        echo ""
        echo "Use --with-deploy to deploy the application."
        exit 0
    fi
    
    # Return actions count for later use
    return $ACTIONS_NEEDED
}

# Ask for confirmation
confirm_proceed() {
    if [ "$AUTO_YES" = true ]; then
        return 0
    fi
    
    echo ""
    read -p "Do you want to proceed? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled by user."
        exit 0
    fi
}

# Install Docker
install_docker() {
    print_header "Installing Docker"
    
    if command -v docker &> /dev/null; then
        print_success "Docker is already installed: $(docker --version)"
        return 0
    fi
    
    echo "Installing Docker prerequisites..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    
    echo "Adding Docker GPG key..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo "Adding Docker repository..."
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    echo "Installing Docker packages..."
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Verify installation
    if docker run --rm hello-world &> /dev/null; then
        print_success "Docker installed successfully!"
    else
        print_error "Docker installation failed!"
        exit 1
    fi
}

# Configure Docker for non-root user
configure_docker_user() {
    print_header "Configuring Docker for Current User"
    
    if groups $USER | grep -q docker; then
        print_success "User already in docker group"
        return 0
    fi
    
    sudo usermod -aG docker $USER
    print_success "Added $USER to docker group"
    print_warning "You may need to logout and login again, or run 'newgrp docker'"
}

# Configure system limits for Kafka
configure_system_limits() {
    print_header "Configuring System Limits for Kafka"
    
    # Check if already configured
    if grep -q "vm.max_map_count=262144" /etc/sysctl.conf 2>/dev/null; then
        print_success "System limits already configured"
        return 0
    fi
    
    echo "Setting vm.max_map_count and fs.file-max..."
    sudo tee -a /etc/sysctl.conf > /dev/null <<EOF

# Kafka Optimizations (added by setup-vps.sh)
vm.max_map_count=262144
fs.file-max=65536
net.core.somaxconn=32768
net.ipv4.tcp_max_syn_backlog=32768
EOF
    
    sudo sysctl -p
    print_success "System limits configured"
}

# Configure firewall
configure_firewall() {
    print_header "Configuring Firewall (UFW)"
    
    if ! command -v ufw &> /dev/null; then
        echo "Installing UFW..."
        sudo apt-get install -y ufw
    fi
    
    echo "Configuring firewall rules..."
    
    # Default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow SSH (important!)
    sudo ufw allow 22/tcp comment 'SSH'
    
    # Application ports
    sudo ufw allow 8080/tcp comment 'Frontend'
    sudo ufw allow 3000/tcp comment 'Backend API'
    sudo ufw allow 3001/tcp comment 'Grafana'
    sudo ufw allow 8081/tcp comment 'Kafka UI'
    sudo ufw allow 9090/tcp comment 'Prometheus'
    
    # Enable firewall (non-interactive)
    echo "y" | sudo ufw enable
    
    print_success "Firewall configured"
    echo ""
    sudo ufw status numbered
}

# Clone and setup project
setup_project() {
    print_header "Setting Up Project"
    
    if [ -d "$PROJECT_DIR" ]; then
        print_warning "Project directory already exists at $PROJECT_DIR"
        read -p "Do you want to update it? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$PROJECT_DIR"
            git pull
        fi
    else
        if [ -z "$REPO_URL" ]; then
            print_warning "REPO_URL not set. Skipping clone."
            print_warning "Please manually clone your repository to $PROJECT_DIR"
            return 0
        fi
        
        echo "Cloning repository..."
        git clone "$REPO_URL" "$PROJECT_DIR"
    fi
    
    cd "$PROJECT_DIR/demo"
    
    # Create .env from example if not exists
    if [ ! -f .env ] && [ -f .env.example ]; then
        cp .env.example .env
        print_success "Created .env from .env.example"
        print_warning "Please review and update .env with your settings"
    fi
}

# Start application
start_application() {
    print_header "Starting Application"
    
    cd "$PROJECT_DIR/demo"
    
    echo "Building and starting containers..."
    docker compose up -d --build
    
    echo ""
    echo "Waiting for services to be healthy..."
    sleep 10
    
    # Check status
    docker compose ps
    
    print_success "Application started!"
}

# Print summary
print_summary() {
    print_header "Setup Complete!"
    
    echo -e "📁 Project Directory: ${GREEN}$PROJECT_DIR${NC}"
    echo ""
    echo "🌐 Access your services:"
    echo -e "   Frontend:    ${GREEN}http://YOUR_VPS_IP:8080${NC}"
    echo -e "   Backend API: ${GREEN}http://YOUR_VPS_IP:3000${NC}"
    echo -e "   Grafana:     ${GREEN}http://YOUR_VPS_IP:3001${NC} (admin/admin)"
    echo -e "   Kafka UI:    ${GREEN}http://YOUR_VPS_IP:8081${NC}"
    echo -e "   Prometheus:  ${GREEN}http://YOUR_VPS_IP:9090${NC}"
    echo ""
    echo "📋 Useful Commands:"
    echo "   cd $PROJECT_DIR/demo"
    echo "   docker compose up -d        # Start services"
    echo "   docker compose down         # Stop services"
    echo "   docker compose logs -f      # View logs"
    echo "   docker compose ps           # Check status"
    echo ""
    
    if ! groups $USER | grep -q docker; then
        print_warning "Remember to logout and login again to use Docker without sudo"
    fi
}

# Show help
show_help() {
    echo "Kafka Demo - VPS Setup Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --check          Only check what needs to be done (dry-run)"
    echo "  --with-deploy    Also clone and start the application"
    echo "  --yes, -y        Skip confirmation prompts (auto-approve)"
    echo "  --help, -h       Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  REPO_URL         Git repository URL for --with-deploy"
    echo "  PROJECT_DIR      Target directory (default: ~/kafka-demo)"
    echo ""
    echo "Examples:"
    echo "  $0 --check                    # See what will be done"
    echo "  $0                            # Setup with confirmation"
    echo "  $0 --yes                      # Setup without confirmation"
    echo "  $0 --with-deploy --yes        # Full setup + deploy"
    echo "  REPO_URL=git@... $0 --with-deploy"
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════╗"
    echo "║     Kafka Demo - VPS Setup Script         ║"
    echo "║     Ubuntu 22.04 / 24.04 LTS              ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
    
    WITH_DEPLOY=false
    AUTO_YES=false
    CHECK_ONLY=false
    
    # Parse arguments
    for arg in "$@"; do
        case $arg in
            --with-deploy)
                WITH_DEPLOY=true
                ;;
            --yes|-y)
                AUTO_YES=true
                ;;
            --check)
                CHECK_ONLY=true
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $arg"
                show_help
                exit 1
                ;;
        esac
    done
    
    check_root
    check_requirements
    
    # Run preflight check
    preflight_check
    
    # If check only, exit here
    if [ "$CHECK_ONLY" = true ]; then
        echo ""
        print_success "Check complete. Run without --check to proceed."
        exit 0
    fi
    
    # Ask for confirmation
    confirm_proceed
    
    echo ""
    
    # Execute setup steps
    install_docker
    configure_docker_user
    configure_system_limits
    configure_firewall
    
    if [ "$WITH_DEPLOY" = true ]; then
        setup_project
        start_application
    fi
    
    print_summary
}

# Run main function
main "$@"
