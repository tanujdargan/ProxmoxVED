#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/tanujdargan/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts
# Author: tanujdargan
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr

# Set default value for VERB if not already set
: ${VERB:=0}

# App Default Values
APP="Byparr"
var_tags="arr;community-script"
var_cpu="2"
var_ram="2048"
var_disk="4"
var_os="debian"
var_version="12"
var_unprivileged="1"

# Print debug information to track verbosity settings
echo "VERB setting: $VERB"

header_info "$APP"
variables
color
catch_errors

# Print debug information after variables are set
echo "VERB after variables: $VERB"

# Ensure VERB is passed correctly to the installation script
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
  $STD git pull
  $STD source $HOME/.local/bin/env || true
  $STD uv sync --group test
  $STD systemctl restart byparr.service
  msg_ok "Updated Byparr"
  exit
}

echo "Starting container setup..."
start
echo "After start()..."

echo "Starting build_container..."
build_container
echo "After build_container..."

description
echo "After description..."

# Add USB passthrough configuration for privileged containers
if [ "$CT_TYPE" == "0" ]; then
  msg_info "Adding USB passthrough configuration"
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
  msg_info "Restarting container to apply changes"
  pct restart ${CTID}
  sleep 5
  msg_ok "Container restarted"
fi

# Ensure root password is set properly
echo "Setting root password..."
msg_info "Setting root password"
pct exec "$CTID" -- bash -c "echo 'root:root' | chpasswd"
msg_ok "Root password set"
echo "Root password set complete"

msg_ok "Completed Successfully!\n"
msg_info "Byparr setup has been successfully initialized!"
msg_info "Access it using the following URL: http://${IP}:8191"
msg_info "Container IP address: ${IP}"
msg_info "Default login credentials:"
msg_info "Username: root"
msg_info "Password: root"
echo "Script execution completed"
