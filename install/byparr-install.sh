#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: Tanuj Dargan
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr/

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
    apt-transport-https \
    gpg \
    xvfb \
    git
msg_ok "Installed Dependencies"

# Installing Chrome
msg_info "Installing Chrome"
wget -qO- https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
$STD apt update
$STD apt install -y google-chrome-stable
msg_ok "Installed Chrome"

# Installing UV Package Manager
msg_info "Installing UV Package Manager"
$STD curl -LsSf -o /tmp/uv-install.sh https://astral.sh/uv/install.sh
$STD chmod +x /tmp/uv-install.sh
$STD /tmp/uv-install.sh
# Make sure we source the env file properly
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'source "$HOME/.local/bin/env"' >> ~/.bashrc
eval "source $HOME/.local/bin/env || true"
msg_ok "Installed UV Package Manager"

# Installing Byparr
msg_info "Installing Byparr"
$STD git clone https://github.com/ThePhaseless/Byparr.git /opt/byparr
cd /opt/byparr
$STD uv sync --group test
msg_ok "Installed Byparr"

# Installing Byparr Service
msg_info "Creating Byparr Service"

# Create the systemd service file
cat << 'EOF' > /etc/systemd/system/byparr.service
[Unit]
Description=Byparr Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/byparr
ExecStart=/bin/bash -c "source $HOME/.local/bin/env && uv sync && ./cmd.sh"
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

$STD systemctl enable -q --now byparr.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
$STD rm -f /tmp/uv-install.sh
msg_ok "Cleaned"
