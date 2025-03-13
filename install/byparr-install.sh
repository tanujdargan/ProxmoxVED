#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: tanujdargan
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr

# Import Functions and Setup
source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# Installing Dependencies
msg_info "Installing Dependencies"
$STD apt-get update
$STD apt-get install -y \
  curl \
  sudo \
  mc \
  apt-transport-https \
  gpg \
  xvfb \
  git \
  wget
msg_ok "Installed Dependencies"

# Installing Chrome
msg_info "Installing Chrome"
$STD wget -qO- https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
$STD apt-get update
$STD apt-get install -y google-chrome-stable
msg_ok "Installed Chrome"

# Installing UV Package Manager
msg_info "Installing UV Package Manager"
$STD curl -LsSf https://astral.sh/uv/install.sh | sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'source "$HOME/.local/bin/env"' >> ~/.bashrc
$STD source $HOME/.local/bin/env || true
msg_ok "Installed UV Package Manager"

# Installing Byparr
msg_info "Installing Byparr"
$STD git clone https://github.com/ThePhaseless/Byparr.git /opt/byparr
cd /opt/byparr
$STD source $HOME/.local/bin/env || true
$STD uv sync --group test

# Create startup wrapper script
cat <<EOF >/opt/byparr/start-byparr.sh
#!/bin/bash

# Source the environment file to set up PATH
if [ -f /root/.local/bin/env ]; then
  source /root/.local/bin/env
fi

# Change to the Byparr directory
cd /opt/byparr

# Run UV sync and start the application
uv sync && ./cmd.sh
EOF

# Make the wrapper script executable
$STD chmod +x /opt/byparr/start-byparr.sh

# Create Byparr version file for update checks
BYPARR_VERSION=$(cd /opt/byparr && git rev-parse --short HEAD)
echo "${BYPARR_VERSION}" > /opt/Byparr_version.txt
msg_ok "Installed Byparr"

# Creating Service
msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/byparr.service
[Unit]
Description=Byparr
After=network.target
[Service]
SyslogIdentifier=byparr
Restart=always
RestartSec=5
Type=simple
Environment="LOG_LEVEL=info"
Environment="CAPTCHA_SOLVER=none"
Environment="PATH=/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
WorkingDirectory=/opt/byparr
ExecStart=/opt/byparr/start-byparr.sh
TimeoutStopSec=60
[Install]
WantedBy=multi-user.target
EOF
$STD systemctl daemon-reload
$STD systemctl enable --now byparr.service
msg_ok "Created Service"

# Setting up SSH access
msg_info "Setting up system access"
$STD sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
$STD sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
$STD sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
$STD systemctl restart sshd
msg_ok "System access configured"

# Set root password
msg_info "Setting root password"
$STD passwd --delete root
$STD echo -e 'root\nroot' | passwd root
$STD echo 'root:root' | chpasswd
msg_ok "Root password set"

motd_ssh
customize

# Cleanup
msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
