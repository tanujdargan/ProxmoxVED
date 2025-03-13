#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/tanujdargan/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: tanujdargan
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr

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
    msg_info "Updating ${APP}"
    cd /opt/byparr
    $STD git pull
    $STD source /root/.local/bin/env
    $STD uv sync --group test
    $STD systemctl restart byparr.service
    msg_ok "Updated ${APP}"
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8191${CL}"
echo -e "${INFO}${YW} Default login credentials:${CL}"
echo -e "${TAB}${YW}Username: root${CL}"
echo -e "${TAB}${YW}Password: root${CL}"
