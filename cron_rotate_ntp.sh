#!/bin/bash

# Debug
#set -x
set -Eeo pipefail

################################################################################
# Every time this script runs, it will update the ntp servers with new ones
################################################################################

# Save script dir
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# Check for get script and run it
GET_SCR="$SCRIPT_DIR/get_random_servers.sh"
[ -x "$GET_SCR" ] || (echo "Error, get ntp script not found: $GET_SCR"; exit)
if [ -x "/bin/bash" ]; then
  source "$GET_SCR" 5
else
  sh "$GET_SCR" 5
fi

# Make sure output file isn't empty
if [ ! -s "$OUTPUT_FILE" ]; then
  echo "Error, output file not found: $OUTPUT_FILE
Error when running get script: $GET_SCR"
  exit
fi

# TODO: Check for ntpd/xntp and update servers
# TODO: Check for chrony
# Check for timedatectl and update servers
if command -v timedatectl &> /dev/null; then
  # Check for config file and back it up
  NTP_CONF="/etc/systemd/timesyncd.conf"
  if [ ! -f "$NTP_CONF" ]; then
    echo "Error, NTP config file not found for timedatectl/timesyncd: $NTP_CONF"
    exit
  fi
  # Halt ntp temporarily
  sudo timedatectl set-ntp false # TODO: Test
  # Populate ntp line
  NTP_LINE="NTP="
  while read -r LINE; do
    NTP_LINE="${NTP_LINE}${LINE} "
  done < "$OUTPUT_FILE"
  # Update conf file, remove ntp servers and replace
  sudo sed -i.old '/^NTP=/d' "$NTP_CONF"
  echo "$NTP_LINE" | sudo tee -a "$NTP_CONF"
  # Restart service
  sudo systemctl restart systemd-timesyncd.service
  sudo timedatectl set-ntp true
# Check for OpenWRT device and update servers
elif command -v opkg &> /dev/null; then
  uci -q delete system.ntp.server
  while read -r LINE; do
    uci add_list system.ntp.server="$LINE"
  done < "$OUTPUT_FILE"
  uci commit system
  rm "$OUTPUT_FILE"
# Else, warn
else
  echo "Error, timedatectl not found and no OpenWRT device detected, exiting."
  exit
fi
