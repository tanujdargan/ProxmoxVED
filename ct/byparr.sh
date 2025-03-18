#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Tanuj Dargan
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr/

APP="Byparr"
var_tags="arr;community-script"
var_cpu="2"
var_ram="2048"
var_disk="8"
var_os="debian"
var_version="12"
var_unprivileged="1"
var_verbose="yes"

header_info "$APP"
variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources

    if [[ ! -d "/opt/byparr" ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi

    msg_info "Stopping $APP"
    systemctl stop byparr
    msg_ok "Stopped $APP"

    msg_info "Updating $APP"
    cd /opt/byparr
    $STD git stash
    $STD git pull
    $STD source $HOME/.local/bin/env || true
    $STD uv sync --group test
    msg_ok "Updated $APP"

    msg_info "Starting $APP"
    systemctl start byparr
    msg_ok "Started $APP"

    msg_ok "Update Successful"
    exit
}

start
build_container

# Add debugging info here
msg_info "Checking for installation script"
$STD curl -s -I https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/install/byparr-install.sh
$STD ls -la /usr/local/community-scripts/logs/
$STD cat /usr/local/community-scripts/logs/$(date '+%Y-%m-%d')_byparr.log

description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8191${CL}"
