#!/bin/bash

# Debug
#set -x
set -Eeo pipefail

# Save script dir
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

################################################################################
IP_FILE="$SCRIPT_DIR/all_ntp_servers.txt"
################################################################################

# Save content from link (arg $1) to a file (arg $2) quietly
get_web() {
  local LINK="$1"
  local FILE="$2"
  [ -n "$LINK" ] || (echo "Error, no link found"; exit 1)
  if [ -z "$FILE" ]; then
    echo "Error, no file path passed"
    exit 1
  elif [ -f "$FILE" ]; then
    rm "$FILE"
  fi
  wget -q "$LINK" -O "$FILE"
}

# Function to pull current NIST.gov servers and save to a file (arg $1)
pull_nist() {
  local OUTPUT_FILE="$1"
  [ -n "$OUTPUT_FILE" ] || (echo "Error, no file path found"; exit 1)
  local NIST_LINK="https://tf.nist.gov/tf-cgi/servers.cgi"
  local TEMP_FILE
  TEMP_FILE=$(mktemp /tmp/randntp.XXXXXX || exit 1)
  echo "Getting NIST servers from: $NIST_LINK"
  get_web "$NIST_LINK" "$TEMP_FILE"
  if [ -f "$TEMP_FILE" ]; then
    # Get ips of running and available servers
    grep -B 9 -iF "All services available" "$TEMP_FILE" | \
      grep -F "<td align = \"center\">" | cut -d ">" -f 2 | \
      sed '/[a-zA-Z]/d' >> "$OUTPUT_FILE"
  else
    echo "Error pulling nist servers from: $NIST_LINK"
    exit 1
  fi
  rm "$TEMP_FILE"
}

# Subprocess for test_ntp_org to make parallelism easier, take link var (arg $1) and return ip
download_ntp_org_process() {
  local LINK="$1"
  [ -n "$LINK" ] || (echo "Error, no link found"; exit 1)
  local TEMP_FILE
  TEMP_FILE=$(mktemp /tmp/randntp.XXXXXX || exit 1)
  get_web "$LINK" "$TEMP_FILE"
  if ! grep -qF "RestrictedAccess" < "$TEMP_FILE" && grep -qF "OpenAccess" < "$TEMP_FILE"; then
    IP=$(sed -n -e 's/^.*IP Address //p' "$TEMP_FILE" | cut -d " " -f 2 || true)
    if [[ "$IP" =~ ^[0-9.]+$ ]]; then
      echo "$IP"
    fi
  fi
  rm -f "$TEMP_FILE"
}

# Tests a piped server ntp.org partial link and returns ip address if good
test_ntp_org() {
  while read -r LINK_END; do
    [ -n "$LINK_END" ] || (echo "Error, partial link not found"; exit 1)
    local LINK="https://support.ntp.org$LINK_END"
    download_ntp_org_process "$LINK" &
  done
  wait
}

# Function to pull stratum one US servers from ntp.org and save to a file (arg $1)
pull_s1_ntp_org() {
  local OUTPUT_FILE="$1"
  [ -n "$OUTPUT_FILE" ] || (echo "Error, no file path found"; exit 1)
  local S1_LINK="https://support.ntp.org/Servers/StratumOneTimeServers"
  local TEMP_FILE
  TEMP_FILE=$(mktemp /tmp/randntp.XXXXXX || exit 1)
  echo "Getting ntp.org stratum one server list from: $S1_LINK"
  get_web "$S1_LINK" "$TEMP_FILE"
  echo "Downloading $S1_LINK servers..."
  grep -F "/Servers/PublicTimeServer" "$TEMP_FILE" | grep -F "\">US" | \
    cut -d "\"" -f 6 | test_ntp_org >> "$OUTPUT_FILE"
  rm "$TEMP_FILE"
}

# Function to pull stratum two US servers from ntp.org and save to a file (arg $1)
pull_s2_ntp_org() {
  local OUTPUT_FILE="$1"
  [ -n "$OUTPUT_FILE" ] || (echo "Error, no file path found"; exit 1)
  local S2_LINK="https://support.ntp.org/Servers/StratumTwoTimeServers"
  local TEMP_FILE
  TEMP_FILE=$(mktemp /tmp/randntp.XXXXXX || exit 1)
  echo "Getting ntp.org stratum two server list from: $S2_LINK"
  get_web "$S2_LINK" "$TEMP_FILE"
  echo "Downloading $S2_LINK servers..."
  grep -F "/Servers/PublicTimeServer" "$TEMP_FILE" | grep -F "\">US" | \
    cut -d "\"" -f 6 | test_ntp_org >> "$OUTPUT_FILE"
  rm "$TEMP_FILE"
}

# Remove existing ip file
rm -f "$IP_FILE"
# Get servers
pull_nist "$IP_FILE"
pull_s1_ntp_org "$IP_FILE"
pull_s2_ntp_org "$IP_FILE"
# Delete any ipv6 addresses from file
[ -f "$IP_FILE" ] && sed -i /::/d "$IP_FILE"
# Sort servers
TEMP_FILE=$(mktemp /tmp/randntp.XXXXXX || exit 1)
cp "$IP_FILE" "$TEMP_FILE"
sort -n "$TEMP_FILE" | uniq > "$IP_FILE"
rm -f "$TEMP_FILE"
# Notify
echo "Saved $(wc -l < "$IP_FILE") ipv4 ntp servers to: $IP_FILE"
