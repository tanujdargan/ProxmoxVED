#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: tanujdargan
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr

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
  wget \
  gpg \
  xvfb \
  git
msg_ok "Installed Dependencies"

# Installing Google Chrome
msg_info "Installing Google Chrome"
$STD wget -q -O /tmp/google-key.pub https://dl.google.com/linux/linux_signing_key.pub
$STD cat /tmp/google-key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
$STD apt-get update
$STD apt-get install -y google-chrome-stable
msg_ok "Installed Google Chrome"

# Installing UV Package Manager
msg_info "Installing UV Package Manager"
$STD curl -LsSf https://astral.sh/uv/install.sh | sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'source "$HOME/.local/bin/env"' >> ~/.bashrc
$STD source $HOME/.local/bin/env || true
msg_ok "Installed UV Package Manager"

# Setting up Byparr
msg_info "Setting up ${APPLICATION}"
$STD git clone https://github.com/ThePhaseless/Byparr.git /opt/byparr
cd /opt/byparr
$STD source $HOME/.local/bin/env || true
$STD uv sync --group test
# Create version file for update checks
RELEASE=$(cd /opt/byparr && git rev-parse --short HEAD)
echo "${RELEASE}" > "/opt/${APPLICATION}_version.txt"
msg_ok "Setup ${APPLICATION}"

# Creating startup wrapper script
msg_info "Creating startup wrapper script"
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
$STD chmod +x /opt/byparr/start-byparr.sh
msg_ok "Created startup wrapper script"

# Creating Service
msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/byparr.service
[Unit]
Description=${APPLICATION} Service
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
msg_info "Setting up SSH access"
$STD sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
$STD sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
$STD sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
$STD systemctl restart sshd
msg_ok "Set up SSH access"

# Setting root password
msg_info "Setting root password"
$STD echo 'root:root' | chpasswd
msg_ok "Set root password"

# Set up console auto-login
msg_info "Setting up console auto-login"
$STD mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat <<EOF >/etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I \$TERM
EOF
$STD systemctl daemon-reload
msg_ok "Set up console auto-login"

motd_ssh
customize

# Cleanup
msg_info "Cleaning up"
$STD rm -f /tmp/google-key.pub
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
