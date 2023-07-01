#!/bin/bash

# Debug
#set -x
set -Eeo pipefail

# Save script dir
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

################################################################################
IP_FILE="$SCRIPT_DIR/all_ntp_servers.txt"
GEN_SCR="$SCRIPT_DIR/update_ntp_server_list.sh"
OUTPUT_FILE="/tmp/random_ntp_servers.txt"
################################################################################

# Check for max server number passed as arg $1
if [ -n "$1" ]; then 
  MAX_SERVERS="$1"
else
  # Select random number with uuid data
  MAX_SERVERS=$(tr -cd '3-9' < /proc/sys/kernel/random/uuid | head -c 1)
fi

# Check for server list, generate one if missing
if [ -s "$IP_FILE" ]; then
  echo "Found ipv4 ntp server list, continuing with existing file: 
$IP_FILE"
elif [ -x "$GEN_SCR" ]; then
  echo "No existing ipv4 ntp server list found, generating one now:"
  if [ -x "/bin/bash" ]; then
    source "$GEN_SCR"
  else
    sh "$GEN_SCR"
  fi
  [ -f "$IP_FILE" ] || (echo "Error, generating server file failed"; exit 1)
else
  echo "Error, executable generate script missing: $GEN_SCR
  make sure script is present and executable with:
  chmod +x $GEN_SCR"
  exit 1
fi

# Prep temp and output file
rm -f "$OUTPUT_FILE"
TEMP_FILE=$(mktemp /tmp/randntp.XXXXXX || exit 1)
# Remove all comments, commented lines, and remove ipv6
sed 's/\#.*//' "$IP_FILE" | sed '/^$/d' | sed /::/d > "$TEMP_FILE"
TOTAL_NUM_SERVERS=$(wc -l < "$TEMP_FILE")
# Test for overflow
if [[ "$MAX_SERVERS" -gt "$TOTAL_NUM_SERVERS" ]]; then 
  MAX_SERVERS="$TOTAL_NUM_SERVERS"
fi
# Select a subset of servers
for i in $(seq 1 "$MAX_SERVERS"); do 
  LINE=$(tr -cd '1-9' < /proc/sys/kernel/random/uuid | head -c 1)
  head -n "$LINE" < "$TEMP_FILE" | tail -n 1 >> "$OUTPUT_FILE"
done
# Sort and remove duplicates
sort -n "$OUTPUT_FILE" | uniq > "$TEMP_FILE"
mv "$TEMP_FILE" "$OUTPUT_FILE"
# Notify of completion
echo "
--------------------------------------------------------------------------------
Finished, selected these $(wc -l < "$OUTPUT_FILE") ntp servers out of $TOTAL_NUM_SERVERS available:
$(cat "$OUTPUT_FILE")

These randomly selected servers have been saved to the file:
$OUTPUT_FILE
--------------------------------------------------------------------------------"
