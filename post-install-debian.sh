#!/bin/bash
set -e

# Create normal user "sluser" if not exists & add to sudo group
if ! id -u sluser &>/dev/null; then
    useradd -m -s /bin/bash sluser
fi
usermod -aG sudo sluser

# Set up SSH key for sluser
install -d -m 700 /home/sluser/.ssh
cat << 'EOF' > /home/sluser/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIX8cmDGQD13jd2GauLEVRdzElm70+yRr1o+8zcN/D37
EOF
chmod 600 /home/sluser/.ssh/authorized_keys
chown -R sluser:sluser /home/sluser/.ssh

# Configure SSH: allow root login and password authentication
sed -i -e 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' \
       -e 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
[ -d /etc/ssh/sshd_config.d ] && rm -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
systemctl restart ssh

# Update and upgrade system, install QEMU Guest Agent
apt-get update && apt-get -y upgrade
apt-get install -y qemu-guest-agent
systemctl restart qemu-guest-agent

# Install Docker
sh <(curl -sSL https://get.docker.com)

# Install Docker Compose
LATEST=$(curl -sL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
DOCKER_CONFIG=${DOCKER_CONFIG:-/root/.docker}
mkdir -p "$DOCKER_CONFIG/cli-plugins"
curl -sSL "https://github.com/docker/compose/releases/download/$LATEST/docker-compose-linux-x86_64" -o "$DOCKER_CONFIG/cli-plugins/docker-compose"
chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose"
docker compose version

echo "Post-install configuration complete."
