#!/bin/bash
set -e

read -p "Execute Step 1 (Basic Setup)? (yes/no): " ans1
if [[ "$ans1" == "yes" ]]; then
    # Create user 'sluser' if missing, add to sudo.
    if ! id -u sluser &>/dev/null; then
        adduser --disabled-password --gecos "" sluser
        usermod -aG sudo sluser
    fi

    # Set up SSH key for 'sluser'
    su - sluser -c 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIX8cmDGQD13jd2GauLEVRdzElm70+yRr1o+8zcN/D37" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'

    # Install and enable the Proxmox Guest Agent.
    apt-get update && apt-get install -y qemu-guest-agent
    systemctl enable qemu-guest-agent && systemctl start qemu-guest-agent

    # Ensure SSH server is installed and running.
    apt-get install -y openssh-server
    systemctl enable ssh && systemctl start ssh
fi

read -p "Execute Step 2 (LibreChat Environment Setup)? (yes/no): " ans2
if [[ "$ans2" == "yes" ]]; then
    # Update package list.
    apt-get update

    # Install Docker prerequisites.
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

    # Add Docker's official GPG key and repository.
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update

    # Install Docker CE (not docker.io).
    apt-get install -y docker-ce

    # Add 'sluser' to the docker group for non-root usage.
    usermod -aG docker sluser

    # Install Docker Compose (v2.26.1).
    curl -L "https://github.com/docker/compose/releases/download/v2.26.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Install Git, Node.js, and npm.
    apt-get install -y git nodejs npm
fi
