#!/bin/bash

# ============================================
# GitHub Actions Self-Hosted Runner Setup Script
# ============================================
# Supports: Ubuntu 22.04 / 24.04 LTS
# Usage: ./setup-runner.sh [options]
#
# Options:
#   --check          Only check current status (all runners)
#   --uninstall      Remove a runner
#   --update         Update runner to latest version
#   --list           List all installed runners
#   --help, -h       Show this help message
#
# Required Environment Variables:
#   GITHUB_REPO_URL  - Repository URL (e.g., https://github.com/user/repo)
#                      OR GitHub org URL for org-level runner
#   GITHUB_TOKEN     - Personal Access Token with repo/admin:org scope
#
# Optional Environment Variables:
#   RUNNER_NAME      - Custom runner name (default: hostname-reponame)
#   RUNNER_LABELS    - Comma-separated labels (default: self-hosted,linux,x64)
#   RUNNER_DIR       - Installation directory (auto-generated if not set)
#   RUNNER_SCOPE     - "repo" or "org" (default: repo)
#
# Multi-Runner Support:
#   This script supports multiple runners on the same VPS.
#   Each runner is installed in a separate directory:
#   ~/actions-runners/<repo-name>/
#
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Base directory for all runners
RUNNERS_BASE_DIR="${RUNNERS_BASE_DIR:-$HOME/actions-runners}"

# Configuration (can be overridden by env vars)
RUNNER_NAME="${RUNNER_NAME:-}"  # Will be auto-generated if empty
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,linux,x64,vps}"
RUNNER_VERSION="${RUNNER_VERSION:-2.331.0}"  # Latest version as of Jan 2025
RUNNER_SCOPE="${RUNNER_SCOPE:-repo}"  # "repo" or "org"

# RUNNER_DIR will be set based on repo name if not provided
RUNNER_DIR="${RUNNER_DIR:-}"

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"
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

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Setup runner user (must run as root)
setup_runner_user() {
    print_header "Setting Up Runner User"
    
    if [[ $EUID -ne 0 ]]; then
        print_error "This command must be run as root!"
        echo "Usage: sudo $0 --setup-user"
        exit 1
    fi
    
    RUNNER_USER="${RUNNER_USER:-runner}"
    
    echo "This will create user '$RUNNER_USER' with:"
    echo "  - Home directory: /home/$RUNNER_USER"
    echo "  - Docker access (docker group)"
    echo "  - Sudo access (no password required)"
    echo ""
    
    # Check if user exists
    if id "$RUNNER_USER" &>/dev/null; then
        print_warning "User '$RUNNER_USER' already exists"
        read -p "Continue to configure permissions? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        echo "Creating user '$RUNNER_USER'..."
        useradd -m -s /bin/bash "$RUNNER_USER"
        print_success "User created"
    fi
    
    # Add to docker group
    echo "Adding to docker group..."
    usermod -aG docker "$RUNNER_USER"
    print_success "Added to docker group"
    
    # Setup sudo without password
    echo "Configuring sudo access..."
    echo "$RUNNER_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$RUNNER_USER
    chmod 440 /etc/sudoers.d/$RUNNER_USER
    print_success "Sudo configured (no password required)"
    
    # Set password with default
    DEFAULT_PASSWORD="Default123"
    echo ""
    echo "Set password for '$RUNNER_USER'"
    echo -e "  (Press Enter for default: ${CYAN}$DEFAULT_PASSWORD${NC})"
    read -sp "Password: " USER_PASSWORD
    echo ""
    
    if [ -z "$USER_PASSWORD" ]; then
        USER_PASSWORD="$DEFAULT_PASSWORD"
        print_info "Using default password: $DEFAULT_PASSWORD"
    fi
    
    echo "$RUNNER_USER:$USER_PASSWORD" | chpasswd
    print_success "Password set successfully"
    
    print_header "User Setup Complete!"
    
    echo "Now switch to the runner user and run the setup:"
    echo ""
    echo -e "  ${CYAN}# Switch to runner user${NC}"
    echo -e "  ${GREEN}su - $RUNNER_USER${NC}"
    echo ""
    echo -e "  ${CYAN}# Clone your repository${NC}"
    echo -e "  ${GREEN}git clone https://github.com/YOUR_USER/YOUR_REPO.git ~/YOUR_REPO${NC}"
    echo ""
    echo -e "  ${CYAN}# Run the setup script${NC}"
    echo -e "  ${GREEN}cd ~/YOUR_REPO/demo/scripts${NC}"
    echo -e "  ${GREEN}GITHUB_REPO_URL=https://github.com/YOUR_USER/YOUR_REPO \\\\${NC}"
    echo -e "  ${GREEN}GITHUB_TOKEN=ghp_xxx ./setup-runner.sh${NC}"
    echo ""
}

# Show help
show_help() {
    echo "GitHub Actions Self-Hosted Runner Setup Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --setup-user     Create and configure runner user (run as root)"
    echo "  --check          Check status of all runners"
    echo "  --list           List all installed runners"
    echo "  --uninstall      Remove a runner (interactive selection)"
    echo "  --update         Update a runner to latest version"
    echo "  --help, -h       Show this help message"
    echo ""
    echo "Required Environment Variables:"
    echo "  GITHUB_REPO_URL  Repository URL (e.g., https://github.com/user/repo)"
    echo "                   Or organization URL for org-level runner"
    echo "  GITHUB_TOKEN     Personal Access Token with 'repo' scope"
    echo "                   (or 'admin:org' for organization runners)"
    echo ""
    echo "Optional Environment Variables:"
    echo "  RUNNER_NAME      Custom runner name (default: hostname-reponame)"
    echo "  RUNNER_LABELS    Comma-separated labels (default: self-hosted,linux,x64,vps)"
    echo "  RUNNER_DIR       Installation directory (default: ~/actions-runners/<repo>)"
    echo "  RUNNER_SCOPE     'repo' or 'org' (default: repo)"
    echo ""
    echo "Multi-Runner Support:"
    echo "  This script supports multiple runners on the same VPS."
    echo "  Each runner is installed in ~/actions-runners/<repo-name>/"
    echo "  You can run this script multiple times for different repos."
    echo ""
    echo "Examples:"
    echo "  # Install runner for repo (interactive)"
    echo "  $0"
    echo ""
    echo "  # Install runner for specific repo"
    echo "  GITHUB_REPO_URL=https://github.com/user/repo1 \\"
    echo "  GITHUB_TOKEN=ghp_xxxx $0"
    echo ""
    echo "  # Install another runner for different repo"
    echo "  GITHUB_REPO_URL=https://github.com/user/repo2 \\"
    echo "  GITHUB_TOKEN=ghp_xxxx $0"
    echo ""
    echo "  # Install organization-level runner (shared across repos)"
    echo "  GITHUB_REPO_URL=https://github.com/my-org \\"
    echo "  RUNNER_SCOPE=org GITHUB_TOKEN=ghp_xxxx $0"
    echo ""
    echo "  # List all runners"
    echo "  $0 --list"
    echo ""
    echo "  # Check status of all runners"
    echo "  $0 --check"
    echo ""
    echo "How to get GITHUB_TOKEN:"
    echo "  For repo runner:  'repo' scope"
    echo "  For org runner:   'admin:org' scope"
    echo "  1. Go to GitHub Settings > Developer settings > Personal access tokens"
    echo "  2. Generate new token (classic) with required scope"
    echo "  3. Copy the token and use it as GITHUB_TOKEN"
    echo ""
}

# Check system requirements
check_requirements() {
    print_header "Checking System Requirements"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "Cannot run as root!"
        echo ""
        echo "GitHub Actions runner must run as a non-root user for security reasons."
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  QUICK SETUP (recommended)${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${CYAN}Step 1: Create runner user (as root)${NC}"
        echo -e "  ${GREEN}$0 --setup-user${NC}"
        echo ""
        echo -e "  ${CYAN}Step 2: Switch to runner user${NC}"
        echo -e "  ${GREEN}su - runner${NC}"
        echo ""
        echo -e "  ${CYAN}Step 3: Clone repo & run setup${NC}"
        echo -e "  ${GREEN}git clone https://github.com/USER/REPO.git ~/REPO${NC}"
        echo -e "  ${GREEN}cd ~/REPO/demo/scripts${NC}"
        echo -e "  ${GREEN}GITHUB_REPO_URL=https://github.com/USER/REPO \\\\${NC}"
        echo -e "  ${GREEN}GITHUB_TOKEN=ghp_xxx ./setup-runner.sh${NC}"
        echo ""
        exit 1
    fi
    
    # Check if running on Linux
    if [[ "$(uname -s)" != "Linux" ]]; then
        print_error "This script only supports Linux"
        exit 1
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
        print_error "Unsupported architecture: $ARCH"
        exit 1
    fi
    
    if [[ "$ARCH" == "aarch64" ]]; then
        RUNNER_ARCH="arm64"
    else
        RUNNER_ARCH="x64"
    fi
    
    print_success "OS: Linux ($ARCH)"
    print_success "User: $USER (non-root)"
    
    # Check required tools
    for cmd in curl tar; do
        if ! command -v $cmd &> /dev/null; then
            print_error "$cmd is required but not installed"
            exit 1
        fi
    done
    print_success "Required tools are available"
    
    # Check Docker (required for the workflow)
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
        print_success "Docker installed: $DOCKER_VERSION"
    else
        print_warning "Docker is not installed. The runner needs Docker to deploy."
        echo "         Run setup-vps.sh first to install Docker."
    fi
    
    # Check if user can run docker without sudo
    if groups $USER 2>/dev/null | grep -q docker; then
        print_success "User is in docker group"
    else
        print_warning "User is not in docker group."
        echo "         Add with: sudo usermod -aG docker $USER"
        echo "         Then logout and login again."
    fi
}

# List all installed runners
list_runners() {
    print_header "Installed Runners"
    
    if [ ! -d "$RUNNERS_BASE_DIR" ]; then
        print_info "No runners installed yet"
        echo "  Base directory: $RUNNERS_BASE_DIR"
        echo "  Install with: $0"
        return
    fi
    
    RUNNER_COUNT=0
    
    for runner_dir in "$RUNNERS_BASE_DIR"/*/; do
        if [ -d "$runner_dir" ] && [ -f "$runner_dir/.runner" ]; then
            RUNNER_COUNT=$((RUNNER_COUNT + 1))
            RUNNER_NAME_FOUND=$(basename "$runner_dir")
            
            # Get runner details
            if command -v jq &> /dev/null && [ -f "$runner_dir/.runner" ]; then
                AGENT_NAME=$(jq -r '.agentName' "$runner_dir/.runner" 2>/dev/null || echo "N/A")
                REPO_URL=$(jq -r '.gitHubUrl' "$runner_dir/.runner" 2>/dev/null || echo "N/A")
            else
                AGENT_NAME="N/A"
                REPO_URL="N/A"
            fi
            
            # Check service status
            if [ -f "$runner_dir/.service" ]; then
                SERVICE_NAME=$(cat "$runner_dir/.service")
                if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                    STATUS="${GREEN}● Running${NC}"
                else
                    STATUS="${YELLOW}○ Stopped${NC}"
                fi
            else
                STATUS="${RED}✗ No service${NC}"
            fi
            
            echo -e "[$RUNNER_COUNT] $RUNNER_NAME_FOUND"
            echo -e "    Status: $STATUS"
            echo "    Name:   $AGENT_NAME"
            echo "    Repo:   $REPO_URL"
            echo "    Dir:    $runner_dir"
            echo ""
        fi
    done
    
    # Also check legacy single runner location
    if [ -d "$HOME/actions-runner" ] && [ -f "$HOME/actions-runner/.runner" ]; then
        RUNNER_COUNT=$((RUNNER_COUNT + 1))
        echo -e "[Legacy] ~/actions-runner"
        if [ -f "$HOME/actions-runner/.service" ]; then
            SERVICE_NAME=$(cat "$HOME/actions-runner/.service")
            if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                echo -e "    Status: ${GREEN}● Running${NC}"
            else
                echo -e "    Status: ${YELLOW}○ Stopped${NC}"
            fi
        fi
        echo ""
    fi
    
    if [ $RUNNER_COUNT -eq 0 ]; then
        print_info "No runners found"
        echo "  Install with: $0"
    else
        echo "Total: $RUNNER_COUNT runner(s)"
    fi
}

# Check if runner is already installed
check_runner_status() {
    print_header "All Runners Status"
    
    TOTAL_RUNNERS=0
    RUNNING_RUNNERS=0
    
    # Check multi-runner directory
    if [ -d "$RUNNERS_BASE_DIR" ]; then
        for runner_dir in "$RUNNERS_BASE_DIR"/*/; do
            if [ -d "$runner_dir" ] && [ -f "$runner_dir/.runner" ]; then
                TOTAL_RUNNERS=$((TOTAL_RUNNERS + 1))
                RUNNER_NAME_FOUND=$(basename "$runner_dir")
                
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "Runner: $RUNNER_NAME_FOUND"
                echo "Directory: $runner_dir"
                
                # Get runner details
                if command -v jq &> /dev/null; then
                    AGENT_NAME=$(jq -r '.agentName' "$runner_dir/.runner" 2>/dev/null || echo "N/A")
                    REPO_URL=$(jq -r '.gitHubUrl' "$runner_dir/.runner" 2>/dev/null || echo "N/A")
                    echo "  Agent Name: $AGENT_NAME"
                    echo "  GitHub URL: $REPO_URL"
                fi
                
                # Check service status
                if [ -f "$runner_dir/.service" ]; then
                    SERVICE_NAME=$(cat "$runner_dir/.service")
                    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                        print_success "Service is running"
                        RUNNING_RUNNERS=$((RUNNING_RUNNERS + 1))
                    else
                        print_warning "Service is stopped"
                        echo "  Start with: sudo $runner_dir/svc.sh start"
                    fi
                else
                    print_warning "Service not installed"
                fi
                echo ""
            fi
        done
    fi
    
    # Check legacy single runner
    if [ -d "$HOME/actions-runner" ] && [ -f "$HOME/actions-runner/.runner" ]; then
        TOTAL_RUNNERS=$((TOTAL_RUNNERS + 1))
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Runner: [Legacy] ~/actions-runner"
        
        if [ -f "$HOME/actions-runner/.service" ]; then
            SERVICE_NAME=$(cat "$HOME/actions-runner/.service")
            if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                print_success "Service is running"
                RUNNING_RUNNERS=$((RUNNING_RUNNERS + 1))
            else
                print_warning "Service is stopped"
            fi
        fi
        echo ""
    fi
    
    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ $TOTAL_RUNNERS -eq 0 ]; then
        print_info "No runners installed"
        echo "Install with: $0"
    else
        echo -e "Total: $TOTAL_RUNNERS runner(s), ${GREEN}$RUNNING_RUNNERS running${NC}"
    fi
}

# Extract owner and repo from GitHub URL
parse_github_url() {
    if [ -z "$GITHUB_REPO_URL" ]; then
        print_error "GITHUB_REPO_URL is required"
        echo ""
        echo "Set it with: export GITHUB_REPO_URL=https://github.com/owner/repo"
        echo "Or provide it when prompted"
        exit 1
    fi
    
    # Check if it's an org URL (no repo part)
    if [[ "$GITHUB_REPO_URL" =~ ^https://github\.com/([^/]+)/?$ ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO=""
        RUNNER_SCOPE="org"
        print_info "Detected organization URL: $OWNER"
    # Check for repo URL
    elif [[ "$GITHUB_REPO_URL" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        print_info "Detected repository: $OWNER/$REPO"
    else
        print_error "Invalid GitHub URL: $GITHUB_REPO_URL"
        echo "Expected format:"
        echo "  Repo: https://github.com/owner/repo"
        echo "  Org:  https://github.com/organization"
        exit 1
    fi
    
    # Set RUNNER_DIR based on repo/org name if not already set
    if [ -z "$RUNNER_DIR" ]; then
        if [ -n "$REPO" ]; then
            RUNNER_DIR="$RUNNERS_BASE_DIR/$REPO"
        else
            RUNNER_DIR="$RUNNERS_BASE_DIR/$OWNER-org"
        fi
    fi
    
    # Set default RUNNER_NAME if not set
    if [ -z "$RUNNER_NAME" ]; then
        if [ -n "$REPO" ]; then
            RUNNER_NAME="$(hostname)-$REPO"
        else
            RUNNER_NAME="$(hostname)-$OWNER"
        fi
    fi
}

# Get registration token from GitHub
get_registration_token() {
    if [ -z "$GITHUB_TOKEN" ]; then
        print_error "GITHUB_TOKEN is required"
        echo ""
        echo "Set it with: export GITHUB_TOKEN=ghp_your_token_here"
        echo "Or provide it when prompted"
        exit 1
    fi
    
    parse_github_url
    
    if [ "$RUNNER_SCOPE" = "org" ]; then
        echo "Getting registration token for organization: $OWNER..."
        API_URL="https://api.github.com/orgs/$OWNER/actions/runners/registration-token"
    else
        echo "Getting registration token for repo: $OWNER/$REPO..."
        API_URL="https://api.github.com/repos/$OWNER/$REPO/actions/runners/registration-token"
    fi
    
    RESPONSE=$(curl -s -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$API_URL")
    
    # Parse token - handle both "token":"xxx" and "token": "xxx" formats
    TOKEN=$(echo "$RESPONSE" | grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
    
    if [ -z "$TOKEN" ]; then
        print_error "Failed to get registration token"
        echo "Response: $RESPONSE"
        echo ""
        if [ "$RUNNER_SCOPE" = "org" ]; then
            echo "Make sure your GITHUB_TOKEN has 'admin:org' scope"
        else
            echo "Make sure your GITHUB_TOKEN has 'repo' scope"
        fi
        exit 1
    fi
    
    REGISTRATION_TOKEN="$TOKEN"
    print_success "Got registration token (expires at $(echo "$RESPONSE" | grep -o '"expires_at"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' | cut -d'T' -f1,2 | tr 'T' ' '))"
}

# Download and extract runner
download_runner() {
    print_header "Downloading GitHub Actions Runner"
    
    echo "Installation directory: $RUNNER_DIR"
    
    # Create base and runner directory
    mkdir -p "$RUNNERS_BASE_DIR"
    mkdir -p "$RUNNER_DIR"
    cd "$RUNNER_DIR"
    
    # Known hashes for version 2.331.0 (update when version changes)
    declare -A KNOWN_HASHES
    KNOWN_HASHES["x64"]="5fcc01bd546ba5c3f1291c2803658ebd3cedb3836489eda3be357d41bfcf28a7"
    KNOWN_HASHES["arm64"]="e3140808ba6f2c6e3478f4ae35e5a7f81f0c31512c5d7e0c4c0e1e8b8b5e6a7b"  # Update with actual hash
    
    # Determine download URL
    RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
    
    echo "Downloading runner v${RUNNER_VERSION} (${RUNNER_ARCH})..."
    echo "URL: $RUNNER_URL"
    
    # Use shared cache for runner archive
    CACHE_DIR="$RUNNERS_BASE_DIR/.cache"
    mkdir -p "$CACHE_DIR"
    ARCHIVE_FILE="$CACHE_DIR/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
    
    if [ -f "$ARCHIVE_FILE" ]; then
        print_info "Using cached archive"
    else
        curl -L -o "$ARCHIVE_FILE" "$RUNNER_URL"
        
        # Validate hash if known
        if [ -n "${KNOWN_HASHES[$RUNNER_ARCH]:-}" ] && [ "$RUNNER_VERSION" = "2.331.0" ]; then
            echo "Validating checksum..."
            EXPECTED_HASH="${KNOWN_HASHES[$RUNNER_ARCH]}"
            ACTUAL_HASH=$(sha256sum "$ARCHIVE_FILE" | awk '{print $1}')
            
            if [ "$EXPECTED_HASH" = "$ACTUAL_HASH" ]; then
                print_success "Checksum verified"
            else
                print_warning "Checksum mismatch! Expected: $EXPECTED_HASH"
                print_warning "                    Got:      $ACTUAL_HASH"
                read -p "Continue anyway? (y/N) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    rm -f "$ARCHIVE_FILE"
                    exit 1
                fi
            fi
        fi
    fi
    
    echo "Extracting..."
    tar xzf "$ARCHIVE_FILE"
    
    print_success "Runner downloaded and extracted to $RUNNER_DIR"
}

# Configure the runner
configure_runner() {
    print_header "Configuring Runner"
    
    cd "$RUNNER_DIR"
    
    # Get registration token (also parses URL and sets variables)
    get_registration_token
    
    # Determine the URL to use for configuration
    if [ "$RUNNER_SCOPE" = "org" ]; then
        CONFIG_URL="https://github.com/$OWNER"
    else
        CONFIG_URL="https://github.com/$OWNER/$REPO"
    fi
    
    echo "Configuring runner..."
    echo "  Name:   $RUNNER_NAME"
    echo "  Labels: $RUNNER_LABELS"
    echo "  Scope:  $RUNNER_SCOPE"
    echo "  URL:    $CONFIG_URL"
    echo "  Dir:    $RUNNER_DIR"
    echo ""
    
    # Run configuration
    ./config.sh \
        --url "$CONFIG_URL" \
        --token "$REGISTRATION_TOKEN" \
        --name "$RUNNER_NAME" \
        --labels "$RUNNER_LABELS" \
        --work "_work" \
        --replace \
        --unattended
    
    print_success "Runner configured"
}

# Install as a service
install_service() {
    print_header "Installing Runner as Service"
    
    cd "$RUNNER_DIR"
    
    echo "Installing systemd service..."
    sudo ./svc.sh install "$USER"
    
    echo "Starting service..."
    sudo ./svc.sh start
    
    # Enable service to start on boot
    SERVICE_NAME=$(cat .service 2>/dev/null || echo "actions.runner.*")
    sudo systemctl enable "$SERVICE_NAME" 2>/dev/null || true
    
    print_success "Runner service installed and started"
    
    echo ""
    echo "Service status:"
    sudo ./svc.sh status
}

# Select a runner interactively
select_runner() {
    local RUNNERS=()
    local RUNNER_DIRS=()
    
    # Collect runners from multi-runner directory
    if [ -d "$RUNNERS_BASE_DIR" ]; then
        for runner_dir in "$RUNNERS_BASE_DIR"/*/; do
            if [ -d "$runner_dir" ] && [ -f "$runner_dir/.runner" ]; then
                RUNNER_NAME_FOUND=$(basename "$runner_dir")
                RUNNERS+=("$RUNNER_NAME_FOUND")
                RUNNER_DIRS+=("$runner_dir")
            fi
        done
    fi
    
    # Check legacy location
    if [ -d "$HOME/actions-runner" ] && [ -f "$HOME/actions-runner/.runner" ]; then
        RUNNERS+=("[Legacy] actions-runner")
        RUNNER_DIRS+=("$HOME/actions-runner")
    fi
    
    if [ ${#RUNNERS[@]} -eq 0 ]; then
        print_info "No runners found to select"
        return 1
    fi
    
    echo "Available runners:"
    for i in "${!RUNNERS[@]}"; do
        echo "  [$((i+1))] ${RUNNERS[$i]}"
    done
    echo ""
    
    read -p "Select runner (1-${#RUNNERS[@]}): " SELECTION
    
    if [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ "$SELECTION" -ge 1 ] && [ "$SELECTION" -le ${#RUNNERS[@]} ]; then
        SELECTED_RUNNER_DIR="${RUNNER_DIRS[$((SELECTION-1))]}"
        SELECTED_RUNNER_NAME="${RUNNERS[$((SELECTION-1))]}"
        return 0
    else
        print_error "Invalid selection"
        return 1
    fi
}

# Uninstall runner
uninstall_runner() {
    print_header "Uninstalling Runner"
    
    # If RUNNER_DIR is set explicitly, use it; otherwise select interactively
    if [ -n "$RUNNER_DIR" ] && [ -d "$RUNNER_DIR" ]; then
        SELECTED_RUNNER_DIR="$RUNNER_DIR"
    else
        if ! select_runner; then
            return
        fi
    fi
    
    echo "Selected: $SELECTED_RUNNER_DIR"
    echo ""
    
    cd "$SELECTED_RUNNER_DIR"
    
    # Stop and uninstall service
    if [ -f ".service" ]; then
        echo "Stopping service..."
        sudo ./svc.sh stop || true
        
        echo "Uninstalling service..."
        sudo ./svc.sh uninstall || true
    fi
    
    # Remove runner from GitHub
    if [ -f ".runner" ]; then
        echo ""
        echo "To remove the runner from GitHub, you need a removal token."
        read -p "Do you want to remove it from GitHub? (y/N) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [ -z "$GITHUB_TOKEN" ]; then
                read -p "Enter your GitHub token: " GITHUB_TOKEN
            fi
            
            # Try to get GitHub URL from runner config
            if command -v jq &> /dev/null; then
                GITHUB_URL=$(jq -r '.gitHubUrl' ".runner" 2>/dev/null || echo "")
            fi
            
            if [ -n "$GITHUB_TOKEN" ] && [ -n "$GITHUB_URL" ]; then
                # Determine if org or repo
                if [[ "$GITHUB_URL" =~ github\.com/([^/]+)/([^/]+) ]]; then
                    OWNER="${BASH_REMATCH[1]}"
                    REPO="${BASH_REMATCH[2]}"
                    API_URL="https://api.github.com/repos/$OWNER/$REPO/actions/runners/remove-token"
                elif [[ "$GITHUB_URL" =~ github\.com/([^/]+)/?$ ]]; then
                    OWNER="${BASH_REMATCH[1]}"
                    API_URL="https://api.github.com/orgs/$OWNER/actions/runners/remove-token"
                fi
                
                if [ -n "$API_URL" ]; then
                    RESPONSE=$(curl -s -X POST \
                        -H "Accept: application/vnd.github+json" \
                        -H "Authorization: Bearer $GITHUB_TOKEN" \
                        -H "X-GitHub-Api-Version: 2022-11-28" \
                        "$API_URL")
                    
                    REMOVE_TOKEN=$(echo "$RESPONSE" | grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
                    
                    if [ -n "$REMOVE_TOKEN" ]; then
                        ./config.sh remove --token "$REMOVE_TOKEN"
                        print_success "Runner removed from GitHub"
                    fi
                fi
            fi
        fi
    fi
    
    # Ask to remove directory
    echo ""
    read -p "Remove runner directory ($SELECTED_RUNNER_DIR)? (y/N) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$SELECTED_RUNNER_DIR"
        print_success "Runner directory removed"
    fi
    
    print_success "Uninstall complete"
}

# Update runner to latest version
update_runner() {
    print_header "Updating Runner"
    
    # Select runner if not specified
    if [ -z "$RUNNER_DIR" ] || [ ! -d "$RUNNER_DIR" ]; then
        if ! select_runner; then
            return
        fi
        RUNNER_DIR="$SELECTED_RUNNER_DIR"
    fi
    
    cd "$RUNNER_DIR"
    
    # Get latest version
    echo "Checking for latest version..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4 | tr -d 'v')
    
    if [ -z "$LATEST_VERSION" ]; then
        print_error "Failed to get latest version"
        exit 1
    fi
    
    echo "Current version: $RUNNER_VERSION"
    echo "Latest version: $LATEST_VERSION"
    
    if [ "$RUNNER_VERSION" = "$LATEST_VERSION" ]; then
        print_success "Already running latest version"
        return
    fi
    
    echo ""
    read -p "Update to v$LATEST_VERSION? (y/N) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        return
    fi
    
    # Stop service
    if [ -f ".service" ]; then
        echo "Stopping service..."
        sudo ./svc.sh stop
    fi
    
    # Update version and download
    RUNNER_VERSION="$LATEST_VERSION"
    download_runner
    
    # Restart service
    if [ -f ".service" ]; then
        echo "Starting service..."
        sudo ./svc.sh start
    fi
    
    print_success "Runner updated to v$LATEST_VERSION"
}

# Interactive setup
interactive_setup() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  GitHub Actions Self-Hosted Runner Setup      ║"
    echo "║  (Multi-Runner Support)                       ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo ""
    
    # Get GitHub repo URL if not set
    if [ -z "$GITHUB_REPO_URL" ]; then
        echo "Enter your GitHub repository or organization URL"
        echo "  Repo example: https://github.com/username/kafka-demo"
        echo "  Org example:  https://github.com/my-organization"
        read -p "URL: " GITHUB_REPO_URL
        
        if [ -z "$GITHUB_REPO_URL" ]; then
            print_error "URL is required"
            exit 1
        fi
    fi
    
    # Parse URL to set defaults
    parse_github_url
    
    # Check if runner already exists for this repo
    if [ -f "$RUNNER_DIR/.runner" ]; then
        print_warning "Runner already exists at $RUNNER_DIR"
        read -p "Do you want to reconfigure? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    # Get GitHub token if not set
    if [ -z "$GITHUB_TOKEN" ]; then
        echo ""
        if [ "$RUNNER_SCOPE" = "org" ]; then
            echo "Enter your GitHub Personal Access Token"
            echo "  (Needs 'admin:org' scope for organization runners)"
        else
            echo "Enter your GitHub Personal Access Token"
            echo "  (Needs 'repo' scope - create at github.com/settings/tokens)"
        fi
        read -sp "GitHub Token: " GITHUB_TOKEN
        echo ""
        
        if [ -z "$GITHUB_TOKEN" ]; then
            print_error "GitHub Token is required"
            exit 1
        fi
    fi
    
    # Confirm runner name
    echo ""
    echo "Runner name: $RUNNER_NAME"
    read -p "Change name? (Enter for default, or type new name): " NEW_NAME
    if [ -n "$NEW_NAME" ]; then
        RUNNER_NAME="$NEW_NAME"
    fi
    
    # Confirm labels
    echo ""
    echo "Runner labels: $RUNNER_LABELS"
    read -p "Change labels? (Enter for default, or type new labels): " NEW_LABELS
    if [ -n "$NEW_LABELS" ]; then
        RUNNER_LABELS="$NEW_LABELS"
    fi
    
    echo ""
    echo "Configuration Summary:"
    if [ "$RUNNER_SCOPE" = "org" ]; then
        echo "  Organization: $OWNER"
        echo "  Scope: Organization (shared across repos)"
    else
        echo "  Repository: $OWNER/$REPO"
        echo "  Scope: Repository"
    fi
    echo "  Runner Name: $RUNNER_NAME"
    echo "  Labels: $RUNNER_LABELS"
    echo "  Install Dir: $RUNNER_DIR"
    echo ""
    
    read -p "Proceed with installation? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi
}

# Print summary after installation
print_summary() {
    print_header "Setup Complete!"
    
    echo "Runner is now active and listening for jobs."
    echo ""
    echo "📋 Runner Details:"
    echo "   Name:      $RUNNER_NAME"
    echo "   Labels:    $RUNNER_LABELS"
    echo "   Directory: $RUNNER_DIR"
    if [ "$RUNNER_SCOPE" = "org" ]; then
        echo "   Scope:     Organization ($OWNER)"
    else
        echo "   Scope:     Repository ($OWNER/$REPO)"
    fi
    echo ""
    echo "📋 Useful Commands:"
    echo "   Check status:    sudo $RUNNER_DIR/svc.sh status"
    echo "   View logs:       journalctl -u actions.runner.* -f"
    echo "   Restart runner:  sudo $RUNNER_DIR/svc.sh restart"
    echo "   Stop runner:     sudo $RUNNER_DIR/svc.sh stop"
    echo "   List all:        $0 --list"
    echo ""
    echo "📋 GitHub Settings:"
    if [ "$RUNNER_SCOPE" = "org" ]; then
        echo "   Manage at: https://github.com/organizations/$OWNER/settings/actions/runners"
    else
        echo "   Manage at: https://github.com/$OWNER/$REPO/settings/actions/runners"
    fi
    echo ""
    echo "📋 Workflow Example:"
    echo "   jobs:"
    echo "     deploy:"
    echo "       runs-on: self-hosted"
    echo "       # Or with specific labels:"
    echo "       runs-on: [self-hosted, vps]"
    echo ""
    echo "📋 Add Another Runner:"
    echo "   GITHUB_REPO_URL=https://github.com/user/another-repo \\"
    echo "   GITHUB_TOKEN=ghp_xxx $0"
    echo ""
}

# Main function
main() {
    # Parse arguments
    case "${1:-}" in
        --setup-user)
            setup_runner_user
            exit 0
            ;;
        --check)
            # Allow root for check/list operations
            check_runner_status
            exit 0
            ;;
        --list)
            list_runners
            exit 0
            ;;
        --uninstall)
            uninstall_runner
            exit 0
            ;;
        --update)
            check_requirements
            update_runner
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            # Interactive setup
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    
    # Run setup
    check_requirements
    interactive_setup
    download_runner
    configure_runner
    install_service
    print_summary
}

# Run main
main "$@"
