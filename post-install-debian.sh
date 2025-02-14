#!/bin/bash
set -e
trap 'echo "Error at line $LINENO. Exiting." >&2' ERR

# Usage: ./post-install-debian.sh [--skip-step1] [--do-step2]
#   --skip-step1 : Skip user, SSH & guest agent setup.
#   --do-step2   : Install Docker, Docker Compose, git, nodejs, and npm.

# Must run as root.
if [ "$(id -u)" -ne 0 ]; then
  echo "Must run as root." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Check for at least 1GB free on root.
check_disk_space() {
  local required_kb=1048576
  local avail_kb
  avail_kb=$(df --output=avail / | tail -1 | tr -d ' ')
  if [ "$avail_kb" -lt "$required_kb" ]; then
    echo "Error: Less than 1GB free on / (available: ${avail_kb} KB). Aborting." >&2
    exit 1
  fi
}

# Clean apt cache and update.
apt_update() {
  apt-get clean
  rm -rf /var/lib/apt/lists/*
  apt-get update -y
}

# Parse arguments.
RUN_STEP1=1
RUN_STEP2=0

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --skip-step1) RUN_STEP1=0 ;;
    --do-step2)   RUN_STEP2=1 ;;
    *) echo "Unknown parameter: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ "$RUN_STEP1" -eq 1 ]; then
  echo "Step 1: Configuring user, SSH, and guest agent..."
  check_disk_space
  apt_update

  # Install OpenSSH server if missing.
  if [ ! -f /etc/ssh/sshd_config ]; then
    apt-get install -y openssh-server
  fi

  # Create user "sluser" with no password and add to sudo.
  if ! id -u sluser &>/dev/null; then
    useradd -m -s /bin/bash sluser
    passwd -d sluser
  fi
  usermod -aG sudo sluser

  # Set up SSH authorized_keys for sluser.
  install -d -m 700 /home/sluser/.ssh
  cat << 'EOF' > /home/sluser/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIX8cmDGQD13jd2GauLEVRdzElm70+yRr1o+8zcN/D37
EOF
  chmod 600 /home/sluser/.ssh/authorized_keys
  chown -R sluser:sluser /home/sluser/.ssh

  # Allow root login & password authentication.
  sed -i -e 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' \
         -e 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
  [ -d /etc/ssh/sshd_config.d ] && rm -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf || true
  if systemctl is-active --quiet ssh; then
    systemctl restart ssh
  else
    systemctl restart sshd
  fi

  # Install and restart QEMU Guest Agent.
  apt-get install -y qemu-guest-agent
  systemctl restart qemu-guest-agent

  echo "Step 1 complete."
fi

if [ "$RUN_STEP2" -eq 1 ]; then
  echo "Step 2: Installing Docker, Docker Compose, git, nodejs, and npm..."
  check_disk_space
  apt_update

  # Ensure curl is present.
  apt-get install -y curl

  # Install Docker.
  sh <(curl -sSL https://get.docker.com)

  # Install Docker Compose.
  LATEST=$(curl -sL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
  DOCKER_CONFIG=${DOCKER_CONFIG:-/root/.docker}
  mkdir -p "$DOCKER_CONFIG/cli-plugins"
  curl -sSL "https://github.com/docker/compose/releases/download/$LATEST/docker-compose-linux-x86_64" -o "$DOCKER_CONFIG/cli-plugins/docker-compose"
  chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose"
  docker compose version

  # Install git, nodejs, and npm.
  apt-get install -y git nodejs npm

  echo "Step 2 complete."
fi

echo "Post-install script complete."
