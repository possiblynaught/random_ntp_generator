#!/bin/bash

# Debug
#set -x
set -Eeo pipefail

# Save script dir
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

################################################################################
IP_FILE="$SCRIPT_DIR/all_ntp_servers.txt"
GENERATE_SCRIPT="$SCRIPT_DIR/update_ntp_server_list.sh"
OUTPUT_FILE="/tmp/random_ntp_servers.txt"
MAX_SERVERS=15
################################################################################

# Check for max server number passed as arg $1
[ -n "$1" ] && MAX_SERVERS="$1"

if [ -f "$IP_FILE" ]; then
  echo "Found ipv4 ntp server list, continuing with existing file: 
$IP_FILE"
elif [ -x "$GENERATE_SCRIPT" ]; then
  echo "No existing ipv4 ntp server list found, generating one now:"
  "${GENERATE_SCRIPT}"
  [ -f "$IP_FILE" ] || (echo "Error, generating server file failed"; exit 1)
else
  echo "Error, executable generate script missing: $GENERATE_SCRIPT
  make sure script is present and executable with:
  chmod +x $GENERATE_SCRIPT"
  exit 1
fi

TEMP_FILE=$(mktemp /tmp/randntp.XXXXXX || exit 1)
# Select a subset of servers
TOTAL_NUM_SERVERS=$(wc -l < "$IP_FILE")
if [[ "$MAX_SERVERS" -gt "$TOTAL_NUM_SERVERS" ]]; then 
  MAX_SERVERS="$TOTAL_NUM_SERVERS"
fi
for i in $(seq 1 "$MAX_SERVERS"); do 
  LINE=$((RANDOM % TOTAL_NUM_SERVERS + 1))
  head -n "$LINE" < "$IP_FILE" | tail -n 1 >> "$TEMP_FILE"
done
# Strip any comments (#) or empty lines
sed -i 's/\#.*//' "$TEMP_FILE"
sed -i '/^$/d' "$TEMP_FILE"
# Sort and remove duplicates
sort -n "$TEMP_FILE" | uniq > "$OUTPUT_FILE"
rm -f "$TEMP_FILE"
# Notify of completion
echo "
--------------------------------------------------------------------------------
Finished, selected these $(wc -l < "$OUTPUT_FILE") ntp servers out of $TOTAL_NUM_SERVERS available:
$(cat "$OUTPUT_FILE")

These randomly selected servers have been saved to the file:
$OUTPUT_FILE
--------------------------------------------------------------------------------"
