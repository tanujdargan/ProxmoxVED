#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/tanujdargan/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts
# Author: tanujdargan
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/community-scripts/Byparr

APP="Byparr"
var_tags="arr;community-script"
var_cpu="2"
var_ram="2048"
var_disk="4"
var_os="debian"
var_version="12"
var_unprivileged="1"

header_info "$APP"
variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources
    if [[ ! -d /opt/byparr ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    msg_info "Updating Byparr"
    cd /opt/byparr
    git pull
    source $HOME/.local/bin/env || true
    uv sync --group test
    systemctl restart byparr.service
    msg_ok "Updated Byparr"
    exit
}

start
build_container
description

msg_info "Installing dependencies..."
$STD apt-get update
$STD apt-get install -y git python3 python3-pip python3-venv curl ufw

msg_info "Installing Byparr..."
$STD mkdir -p /opt/byparr
$STD git clone https://github.com/community-scripts/Byparr.git /opt/byparr
$STD cd /opt/byparr

msg_info "Setting up Python environment..."
$STD python3 -m venv $HOME/.local/bin/env
$STD source $HOME/.local/bin/env
$STD pip install uv
$STD uv sync --group test

msg_info "Creating and configuring Byparr service..."
$STD bash -c 'cat > /etc/systemd/system/byparr.service << EOF
[Unit]
Description=Byparr Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/byparr
ExecStart=$HOME/.local/bin/env/bin/python3 app.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF'

$STD systemctl daemon-reload
$STD systemctl enable byparr.service
$STD systemctl start byparr.service

# Set up proper credentials
USERNAME="admin"
PASSWORD=$(openssl rand -base64 12)
$STD cd /opt/byparr
$STD bash -c "echo '{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}' > /opt/byparr/config/credentials.json"

msg_ok "Byparr installation completed successfully!"

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8191${CL}"
echo -e "${INFO}${YW} Container IP address: ${IP}${CL}"
echo -e "${INFO}${YW} Default login credentials:${CL}"
echo -e "${TAB}${YW}Username: ${USERNAME}${CL}"
echo -e "${TAB}${YW}Password: ${PASSWORD}${CL}"
