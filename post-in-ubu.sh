#!/bin/bash
set -e

# Step 1: Basic Setup
read -p "Do you want to execute Step 1 (Basic Setup)? (yes/no): " answer1
if [[ "$answer1" == "yes" ]]; then
    # Create 'sluser' if missing and add to sudo group.
    if ! id -u sluser &>/dev/null; then
        adduser --disabled-password --gecos "" sluser
        usermod -aG sudo sluser
    fi

    # Set up SSH key for sluser.
    su - sluser -c 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIX8cmDGQD13jd2GauLEVRdzElm70+yRr1o+8zcN/D37" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'

    # Install and enable the Proxmox Guest Agent.
    apt-get update && apt-get install -y qemu-guest-agent
    systemctl enable qemu-guest-agent && systemctl start qemu-guest-agent

    # Ensure SSH service is installed and running.
    apt-get install -y openssh-server
    systemctl enable ssh && systemctl start ssh
fi

# Step 2: Development Setup & LibreChat Optimization
read -p "Do you want to execute Step 2 (Development Setup)? (yes/no): " answer2
if [[ "$answer2" == "yes" ]]; then
    apt-get update && apt-get upgrade -y

    # Install prerequisites for Docker CE.
    apt-get install -y ca-certificates curl gnupg lsb-release

    # Remove any old Docker versions.
    apt-get remove -y docker docker-engine docker.io containerd runc || true

    # Add Docker's official GPG key and set up the repository.
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update

    # Install Docker CE, its CLI, containerd, and the Docker Compose plugin.
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Add sluser to the docker group for non-sudo usage.
    usermod -aG docker sluser

    # Install Git, Node.js, and npm.
    apt-get install -y git nodejs npm

    # (Optional) Clean up package cache.
    apt-get autoremove -y && apt-get clean
fi
