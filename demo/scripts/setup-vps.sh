#!/bin/bash

# Setup script for Kafka Demo on Ubuntu 24.04 LTS
# Usage: ./setup-vps.sh

set -e

echo "🚀 Starting VPS Setup for Kafka Demo..."

# 1. Update system
echo "📦 Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y

# 2. Install Docker
echo "🐳 Installing Docker..."
# Add Docker's official GPG key:
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 3. Verify Docker installation
echo "✅ Verifying Docker installation..."
if docker run --rm hello-world &> /dev/null; then
    echo "   Docker installed successfully!"
else
    echo "❌ Docker installation failed. Please check logs."
    exit 1
fi

# 3.1 Configure System Limits for Kafka
echo "⚙️  Configuring system limits (vm.max_map_count & fs.file-max)..."
sudo tee -a /etc/sysctl.conf <<EOF
# Kafka Optimizations
vm.max_map_count=262144
fs.file-max=65536
EOF
sudo sysctl -p
echo "   System limits updated."

# 4. Setup Project Directory
PROJECT_DIR=~/demo-kafka
echo "📂 Setting up project directory at $PROJECT_DIR..."

# 5. Fix permissions (optional but recommended)
# Add current user to docker group to avoid using sudo for docker commands
sudo usermod -aG docker $USER
echo "   User added to docker group. You may need to logout and login again for this to take effect."

# 6. Check Docker Compose
echo "🐙 Checking Docker Compose..."
docker compose version

echo "✨ Setup complete! To deploy the app, navigate to $PROJECT_DIR and run:"
echo "   docker compose up -d --build"
echo ""
echo "Note: If you just added yourself to the docker group, you might need to run 'newgrp docker' or re-login."
