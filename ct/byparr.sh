#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts
# Author: tanujdargan
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr

# App Default Values
APP="Byparr"
var_tags="arr;community-script"
var_cpu="2"
var_ram="2048"
var_disk="4"
var_os="debian"
var_version="12"
var_unprivileged="1"

# Force debug output regardless of verbose setting
VERBOSITY=1
DEBUG=1
DEBUG_LOG="/tmp/byparr_install_debug.log"

# Debug helper function
debug_log() {
  echo "$(date): $1" | tee -a "$DEBUG_LOG"
}

debug_log "Starting Byparr installation script"

header_info "$APP"
variables
color
catch_errors

debug_log "After initial setup - VERBOSITY=$VERBOSITY VERB=$VERB"

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
  git pull 2>&1 | tee -a "$DEBUG_LOG"
  source $HOME/.local/bin/env || true
  uv sync --group test 2>&1 | tee -a "$DEBUG_LOG"
  systemctl restart byparr.service
  msg_ok "Updated Byparr"
  exit
}

debug_log "About to start container setup"
start
debug_log "After start() - VERBOSITY=$VERBOSITY VERB=$VERB"

# Override build_container to intercept and debug
function original_build_container() {
  build_container
}

function build_container() {
  debug_log "Starting build_container with VERBOSITY=$VERBOSITY VERB=$VERB"

  # Call the original function
  debug_log "Calling original build_container"
  original_build_container

  debug_log "Finished build_container"
}

build_container
debug_log "After build_container - VERBOSITY=$VERBOSITY VERB=$VERB"

description
debug_log "After description"

# Add USB passthrough configuration for privileged containers
if [ "$CT_TYPE" == "0" ]; then
  msg_info "Adding USB passthrough configuration"
  debug_log "Adding USB passthrough for CT_TYPE=$CT_TYPE"
  LXC_CONFIG=/etc/pve/lxc/${CTID}.conf
  cat <<EOF >>$LXC_CONFIG
# USB passthrough
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
lxc.cgroup2.devices.allow: c 188:* rwm
lxc.cgroup2.devices.allow: c 189:* rwm
lxc.mount.entry: /dev/serial/by-id  dev/serial/by-id  none bind,optional,create=dir
lxc.mount.entry: /dev/ttyUSB0       dev/ttyUSB0       none bind,optional,create=file
lxc.mount.entry: /dev/ttyUSB1       dev/ttyUSB1       none bind,optional,create=file
lxc.mount.entry: /dev/ttyACM0       dev/ttyACM0       none bind,optional,create=file
lxc.mount.entry: /dev/ttyACM1       dev/ttyACM1       none bind,optional,create=file
EOF
  msg_ok "Added USB passthrough configuration"

  # Restart the container to apply changes
  debug_log "Restarting container CTID=${CTID}"
  msg_info "Restarting container to apply changes"
  pct restart ${CTID} 2>&1 | tee -a "$DEBUG_LOG"
  sleep 5
  msg_ok "Container restarted"
fi

# Ensure root password is set properly
debug_log "Setting root password for container CTID=${CTID}"
msg_info "Setting root password"
pct exec "$CTID" -- bash -c "echo 'root:root' | chpasswd" 2>&1 | tee -a "$DEBUG_LOG"
msg_ok "Root password set"

debug_log "Installation completed"
msg_ok "Completed Successfully!\n"
debug_log "Final output messages"
msg_info "Byparr setup has been successfully initialized!"
msg_info "Access it using the following URL: http://${IP}:8191"
msg_info "Container IP address: ${IP}"
msg_info "Default login credentials:"
msg_info "Username: root"
msg_info "Password: root"

debug_log "Script execution completed"
