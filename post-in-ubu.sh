#!/bin/bash

# Enable error handling
set -euo pipefail
trap 'error "An error occurred on line $LINENO. Exit code: $?"' ERR

# Utility functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    log "ERROR: $1" >&2
    exit 1
}

confirm() {
    read -p "$1 (yes/no): " answer
    [[ "$answer" == "yes" ]]
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        error "This script must be run as root"
    fi
}

# Part 0: Initial System Setup
setup_system() {
    log "Checking system setup..."
    
    # Check if sluser exists
    if ! id -u sluser &>/dev/null; then
        log "Creating sluser..."
        adduser --disabled-password --gecos "" sluser
        usermod -aG sudo sluser
    else
        log "sluser already exists"
    fi
    
    # Setup SSH directory and key (idempotent)
    su - sluser -c '
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        if ! grep -q "AAAAC3NzaC1lZDI1NTE5AAAAIIX8cmDGQD13jd2GauLEVRdzElm70+yRr1o+8zcN/D37" ~/.ssh/authorized_keys 2>/dev/null; then
            echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIX8cmDGQD13jd2GauLEVRdzElm70+yRr1o+8zcN/D37" >> ~/.ssh/authorized_keys
        fi
        chmod 600 ~/.ssh/authorized_keys
    '
    
    # Install and configure services
    if ! dpkg -l | grep -q qemu-guest-agent; then
        apt-get update
        apt-get install -y qemu-guest-agent
    fi
    
    if ! dpkg -l | grep -q openssh-server; then
        apt-get update
        apt-get install -y openssh-server
    fi
    
    # Enable services (idempotent)
    systemctl enable --now qemu-guest-agent || true
    systemctl enable --now ssh || true
}

# Part I: Docker Installation
install_docker() {
    log "Checking Docker installation..."
    
    # Check if Docker is already installed
    if command -v docker &>/dev/null && docker --version; then
        log "Docker is already installed"
        # Ensure user is in docker group
        if ! groups sluser | grep -q docker; then
            usermod -aG docker sluser
            log "Added sluser to docker group"
        fi
    else
        log "Installing Docker and dependencies..."
        
        # Update and install prerequisites
        apt-get update
        apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            software-properties-common \
            gnupg \
            lsb-release

        # Remove old Docker versions if present
        apt-get remove -y docker docker-engine docker.io containerd runc || true

        # Add Docker's official GPG key (idempotent)
        mkdir -p /etc/apt/keyrings
        if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        fi

        # Add Docker repository (idempotent)
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
            tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Install Docker
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        usermod -aG docker sluser
    fi

    # Check/Install Docker Compose
    if ! command -v docker-compose &>/dev/null; then
        log "Installing Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/download/v2.26.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    else
        log "Docker Compose is already installed"
    fi

    # Ensure Docker is running
    if ! systemctl is-active --quiet docker; then
        systemctl enable docker
        systemctl start docker
    fi
}

# Part II: Development Tools
install_dev_tools() {
    log "Checking development tools..."
    
    local tools_to_install=()
    
    # Check each tool
    if ! command -v git &>/dev/null; then
        tools_to_install+=("git")
    fi
    if ! command -v node &>/dev/null; then
        tools_to_install+=("nodejs")
    fi
    if ! command -v npm &>/dev/null; then
        tools_to_install+=("npm")
    fi
    
    # Install missing tools
    if [ ${#tools_to_install[@]} -ne 0 ]; then
        log "Installing missing tools: ${tools_to_install[*]}"
        apt-get update
        apt-get install -y "${tools_to_install[@]}"
    else
        log "All development tools are already installed"
    fi
}

# Part III: LibreChat Setup
setup_librechat() {
    log "Checking LibreChat setup..."
    
    # Switch to sluser for LibreChat setup
    su - sluser -c '
        cd ~
        if [ ! -d "LibreChat" ]; then
            log "Cloning LibreChat repository..."
            git clone https://github.com/danny-avila/LibreChat.git
        else
            log "LibreChat directory already exists"
        fi
        
        cd LibreChat/
        
        # Create minimal configuration if it doesn't exist
        if [ ! -f "librechat.yaml" ]; then
            cat > librechat.yaml << EOL
version: 1.0.5
cache: true
EOL
        fi
        
        # Setup environment file if it doesn't exist
        if [ ! -f ".env" ]; then
            cp .env.example .env
            log "Created new .env file from example"
        else
            log ".env file already exists"
        fi
        
        # Check if containers are running
        if ! docker-compose -f ./deploy-compose.yml ps | grep -q "Up"; then
            log "Starting Docker containers..."
            docker-compose -f ./deploy-compose.yml up -d
        else
            log "Docker containers are already running"
        fi
    '
}

# Update function
update_librechat() {
    log "Updating LibreChat..."
    su - sluser -c '
        cd ~/LibreChat
        if [ -d ".git" ]; then
            # Store current version
            old_version=$(git describe --tags || git rev-parse --short HEAD)
            
            # Update repository
            git fetch
            new_version=$(git ls-remote --tags origin | sort -V | tail -n1 | cut -f2)
            
            if [ "$old_version" != "$new_version" ]; then
                log "Updating from $old_version to $new_version"
                docker-compose -f ./deploy-compose.yml down
                git pull
                docker-compose -f ./deploy-compose.yml pull
                docker-compose -f ./deploy-compose.yml up -d
                log "Update complete"
            else
                log "Already at latest version ($old_version)"
            fi
        else
            error "LibreChat git repository not found"
        fi
    '
}

# Main execution
main() {
    check_root
    
    if confirm "Do you want to check/perform system setup?"; then
        setup_system
    fi
    
    if confirm "Do you want to check/install Docker and its dependencies?"; then
        install_docker
    fi
    
    if confirm "Do you want to check/install development tools (git, nodejs, npm)?"; then
        install_dev_tools
    fi
    
    if confirm "Do you want to check/setup LibreChat?"; then
        setup_librechat
        log "LibreChat setup verified/completed. Access it at http://yourserverip"
        log "Remember to check/edit .env file with your configuration"
    fi
    
    log "Installation verification/setup complete!"
}

# Script execution
if [ "$1" = "update" ]; then
    check_root
    update_librechat
else
    main
fi
