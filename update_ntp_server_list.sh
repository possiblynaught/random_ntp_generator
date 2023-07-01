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
  wget -q "$LINK" -O "$FILE" || (echo "Error, unable to retrieve servers"; exit)
}

# Function to pull current NIST.gov servers and append to a file (arg $1)
pull_nist() {
  local OUTPUT_FILE="$1"
  [ -n "$OUTPUT_FILE" ] || (echo "Error, no file path passed to pull_nist()"; exit 1)
  local NIST_LINK="https://tf.nist.gov/tf-cgi/servers.cgi"
  local TEMP_FILE
  TEMP_FILE=$(mktemp /tmp/randntp.XXXXXX || exit 1)
  local TEMP_OUTPUT_FILE
  TEMP_OUTPUT_FILE=$(mktemp /tmp/randntp.XXXXXX || exit 1)
  echo "Getting NIST servers from: $NIST_LINK"
  get_web "$NIST_LINK" "$TEMP_FILE"
  echo "# NIST.gov servers:" >> "$TEMP_OUTPUT_FILE"
  if [ -f "$TEMP_FILE" ]; then
    # Get ips of running and available servers
    grep -B 9 -iF "All services available" "$TEMP_FILE" | \
      grep -F "<td align = \"center\">" | cut -d ">" -f 2 | \
      sed '/[a-zA-Z]/d' >> "$TEMP_OUTPUT_FILE"
  else
    echo "Error pulling nist servers from: $NIST_LINK"
    exit 1
  fi
  rm "$TEMP_FILE"
  # Sort and remove duplicates
  sort -n "$TEMP_OUTPUT_FILE" | uniq >> "$OUTPUT_FILE"
  rm -f "$TEMP_OUTPUT_FILE"
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

# Function to pull stratum one US servers from ntp.org and append to a file (arg $1)
pull_s1_ntp_org() {
  local OUTPUT_FILE="$1"
  [ -n "$OUTPUT_FILE" ] || (echo "Error, no file path passed to pull_s1_ntp_org()"; exit 1)
  local S1_LINK="https://support.ntp.org/Servers/StratumOneTimeServers"
  local TEMP_FILE
  TEMP_FILE=$(mktemp /tmp/randntp.XXXXXX || exit 1)
  local TEMP_OUTPUT_FILE
  TEMP_OUTPUT_FILE=$(mktemp /tmp/randntp.XXXXXX || exit 1)
  echo "Getting ntp.org stratum one server list from: $S1_LINK"
  get_web "$S1_LINK" "$TEMP_FILE"
  echo "# ntp.org stratum 1 servers:" >> "$TEMP_OUTPUT_FILE"
  echo "Downloading $S1_LINK servers..."
  grep -F "/Servers/PublicTimeServer" "$TEMP_FILE" | grep -F "\">US" | \
    cut -d "\"" -f 6 | test_ntp_org >> "$TEMP_OUTPUT_FILE"
  rm "$TEMP_FILE"
  # Sort and remove duplicates
  sort -n "$TEMP_OUTPUT_FILE" | uniq >> "$OUTPUT_FILE"
  rm -f "$TEMP_OUTPUT_FILE"
}

# Function to pull stratum two US servers from ntp.org and append to a file (arg $1)
pull_s2_ntp_org() {
  local OUTPUT_FILE="$1"
  [ -n "$OUTPUT_FILE" ] || (echo "Error, no file path passed to pull_s2_ntp_org()"; exit 1)
  local S2_LINK="https://support.ntp.org/Servers/StratumTwoTimeServers"
  local TEMP_FILE
  TEMP_FILE=$(mktemp /tmp/randntp.XXXXXX || exit 1)
  local TEMP_OUTPUT_FILE
  TEMP_OUTPUT_FILE=$(mktemp /tmp/randntp.XXXXXX || exit 1)
  echo "Getting ntp.org stratum two server list from: $S2_LINK"
  get_web "$S2_LINK" "$TEMP_FILE"
  echo "# ntp.org stratum 2 servers:" >> "$TEMP_OUTPUT_FILE"
  echo "Downloading $S2_LINK servers..."
  grep -F "/Servers/PublicTimeServer" "$TEMP_FILE" | grep -F "\">US" | \
    cut -d "\"" -f 6 | test_ntp_org >> "$TEMP_OUTPUT_FILE"
  rm "$TEMP_FILE"
  # Sort and remove duplicates
  sort -n "$TEMP_OUTPUT_FILE" | uniq >> "$OUTPUT_FILE"
  rm -f "$TEMP_OUTPUT_FILE"
}

# Function to resolve a hostname (arg $2) and append to a file (arg $1)
get_host_ips() {
  local OUTPUT_FILE="$1"
  local HOST="$2"
  [ -n "$HOST" ] || (echo "Error, no host passed to get_host_ips()"; exit 1)
  [ -n "$OUTPUT_FILE" ] || (echo "Error, no file path passed to get_host_ips()"; exit 1)
  if command -v getent &> /dev/null; then
    # If command exists, get ips
    getent ahosts "$HOST" | cut -d " " -f 1 >> "$OUTPUT_FILE" || \
      echo "##Error, couldn't resolve: $HOST" >> "$OUTPUT_FILE"
  else
    # If command doesn't exist, add comments instead
    echo "##Error, command 'getent' missing, not resolving $HOST" >> "$OUTPUT_FILE"
  fi
}

# Function to pull ntp servers from US internet/tech companies and append to a file (arg $1)
pull_us_corps() {
  local OUTPUT_FILE="$1"
  [ -n "$OUTPUT_FILE" ] || (echo "Error, no file path passed to pull_us_corps()"; exit 1)
  local TEMP_OUTPUT_FILE
  TEMP_OUTPUT_FILE=$(mktemp /tmp/randntp.XXXXXX || exit 1)
  echo "Getting servers from US companies (google, facebook, cloudflare, hp, ...)"
  # Google
  echo "# Google server(s):" >> "$OUTPUT_FILE"
  get_host_ips "$TEMP_OUTPUT_FILE" "time.google.com"
  get_host_ips "$TEMP_OUTPUT_FILE" "time1.google.com"
  get_host_ips "$TEMP_OUTPUT_FILE" "time2.google.com"
  get_host_ips "$TEMP_OUTPUT_FILE" "time3.google.com"
  get_host_ips "$TEMP_OUTPUT_FILE" "time4.google.com"
  sort -n "$TEMP_OUTPUT_FILE" | uniq >> "$OUTPUT_FILE"
  rm -f "$TEMP_OUTPUT_FILE"
  # Cloudflare
  echo "# Cloudflare server(s):" >> "$OUTPUT_FILE"
  get_host_ips "$TEMP_OUTPUT_FILE" "time.cloudflare.com"
  sort -n "$TEMP_OUTPUT_FILE" | uniq >> "$OUTPUT_FILE"
  rm -f "$TEMP_OUTPUT_FILE"
  # Facebook
  echo "# Facebook server(s):" >> "$OUTPUT_FILE"
  get_host_ips "$TEMP_OUTPUT_FILE" "time.facebook.com"
  get_host_ips "$TEMP_OUTPUT_FILE" "time1.facebook.com"
  get_host_ips "$TEMP_OUTPUT_FILE" "time2.facebook.com"
  get_host_ips "$TEMP_OUTPUT_FILE" "time3.facebook.com"
  get_host_ips "$TEMP_OUTPUT_FILE" "time4.facebook.com"
  get_host_ips "$TEMP_OUTPUT_FILE" "time5.facebook.com"
  sort -n "$TEMP_OUTPUT_FILE" | uniq >> "$OUTPUT_FILE"
  rm -f "$TEMP_OUTPUT_FILE"
  # Microsoft
  echo "# Microsoft server(s):" >> "$OUTPUT_FILE"
  get_host_ips "$TEMP_OUTPUT_FILE" "time.windows.com"
  sort -n "$TEMP_OUTPUT_FILE" | uniq >> "$OUTPUT_FILE"
  rm -f "$TEMP_OUTPUT_FILE"
  # DEC/Compaq/HP
  echo "# HP server(s):" >> "$OUTPUT_FILE"
  get_host_ips "$TEMP_OUTPUT_FILE" "clepsydra.labs.hp.com"
  get_host_ips "$TEMP_OUTPUT_FILE" "clepsydra.hpl.hp.com"
  sort -n "$TEMP_OUTPUT_FILE" | uniq >> "$OUTPUT_FILE"
  rm -f "$TEMP_OUTPUT_FILE"
}

# Remove existing ip file
rm -f "$IP_FILE"
echo "### Lines and comments starting with '#' will be ignored ###" >> "$IP_FILE"
# Get servers
pull_nist "$IP_FILE"
pull_s1_ntp_org "$IP_FILE"
pull_s2_ntp_org "$IP_FILE"
pull_us_corps "$IP_FILE"
# Delete any ipv6 addresses from file
[ -f "$IP_FILE" ] && sed -i /::/d "$IP_FILE"
# Get number of servers in file
NUM_SERVERS=$(sed 's/\#.*//' "$IP_FILE" | sed '/^$/d' | wc -l)
# Notify
echo "Saved $NUM_SERVERS ipv4 ntp servers to: $IP_FILE"
