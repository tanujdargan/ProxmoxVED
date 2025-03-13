#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: tanujdargan
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr

# Print debugging information
echo "VERBOSE=$VERBOSE VERB=$VERB"

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# Force verbose mode for testing
VERB=1
# Redefine STD based on verbose setting
if [ "$VERB" = "1" ]; then
  STD=""
else
  STD=">/dev/null 2>&1"
fi

echo "After setup: VERBOSE=$VERBOSE VERB=$VERB STD=$STD"

msg_info "Installing Dependencies"
$STD apt-get update
$STD apt-get install -y curl sudo mc apt-transport-https wget gpg xvfb git
msg_ok "Installed Dependencies"

msg_info "Installing Chrome"
# More reliable Chrome key handling
$STD curl -s https://dl.google.com/linux/linux_signing_key.pub > /tmp/google-key.pub
if [ ! -s /tmp/google-key.pub ]; then
  $STD wget -q -O /tmp/google-key.pub https://dl.google.com/linux/linux_signing_key.pub
fi

# Verify the key file is not empty and looks valid
if [ ! -s /tmp/google-key.pub ] || ! grep -q "BEGIN PGP PUBLIC KEY BLOCK" /tmp/google-key.pub; then
  msg_error "Invalid or empty Google signing key"
  exit 1
fi

# Import the key
$STD cat /tmp/google-key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
$STD apt-get update
$STD apt-get install -y google-chrome-stable
$STD rm -f /tmp/google-key.pub
msg_ok "Installed Chrome"

msg_info "Installing UV Package Manager"
echo "Starting UV installation - this might take time..."
eval "curl -LsSf https://astral.sh/uv/install.sh | sh"
echo "UV installation completed"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'source "$HOME/.local/bin/env"' >> ~/.bashrc
source $HOME/.local/bin/env || true
msg_ok "Installed UV Package Manager"

msg_info "Installing Byparr"
echo "Cloning Byparr repository..."
eval "git clone https://github.com/ThePhaseless/Byparr.git /opt/byparr"
cd /opt/byparr
source $HOME/.local/bin/env || true
echo "Running uv sync - this might take time..."
eval "uv sync --group test"
echo "UV sync completed"
msg_ok "Installed Byparr"

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
ExecStart=/bin/bash -c "source /root/.local/bin/env && cd /opt/byparr && uv sync && ./cmd.sh"
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
EOF

$STD systemctl daemon-reload
$STD systemctl enable --now byparr.service
msg_ok "Created Service"

msg_info "Setting up system access"
$STD sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
$STD sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
$STD sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
$STD systemctl restart sshd
msg_ok "System access configured"

motd_ssh
customize

msg_info "Setting root password"
eval "passwd --delete root"
eval "echo -e 'root\nroot' | passwd root"
eval "echo 'root:root' | chpasswd"
msg_ok "Root password set"

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned up"

echo ""
echo "======== BYPARR INFORMATION ========"
echo "Service Name: byparr.service"
echo "Port: 8191"
echo "Username: root"
echo "Password: root"
echo "===================================="
