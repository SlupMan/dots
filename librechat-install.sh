#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: tteck
# Co-Author: havardthom
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  sudo \
  mc \
  gpg \
  git \
  ffmpeg \
  python3 \
  python3-pip \
  build-essential
msg_ok "Installed Dependencies"

msg_info "Setting up Node.js Repository"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
$STD apt-get update
msg_ok "Set up Node.js Repository"

msg_info "Installing Node.js"
$STD apt-get install -y nodejs
msg_ok "Installed Node.js"

msg_info "Cloning LibreChat Repository"
$STD git clone https://github.com/LibreChat/LibreChat.git /opt/librechat
cd /opt/librechat
msg_ok "Cloned LibreChat Repository"

msg_info "Installing Python Dependencies"
cd /opt/librechat/backend
$STD pip3 install -r requirements.txt
msg_ok "Installed Python Dependencies"

msg_info "Installing Node.js Dependencies"
cd /opt/librechat
$STD npm install
export NODE_OPTIONS="--max-old-space-size=3584"
$STD npm run build
msg_ok "Installed Node.js Dependencies and Built LibreChat"

msg_info "Creating LibreChat Service"
cat <<EOF >/etc/systemd/system/librechat.service
[Unit]
Description=LibreChat Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/librechat
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now librechat.service
msg_ok "Created and Started LibreChat Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
