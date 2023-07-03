#!/bin/bash

# Debug
#set -x
set -Eeo pipefail

# Save script dir
SCRIPT_DIR=$(dirname "$0")

################################################################################
IP_FILE="$SCRIPT_DIR/all_ntp_servers.txt"
GEN_SCR="$SCRIPT_DIR/update_ntp_server_list.sh"
OUTPUT_FILE="/tmp/random_ntp_servers.txt"
################################################################################

# Get a random number with smallest possible:$1 and largest possible:$2
get_random() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error calling get_random(), one or more args missing within: $(basename "$0")"
    exit
  elif [ "$1" -ge "$2" ] || [ 0 -gt "$1" ] || [ 1 -gt "$2" ]; then
    echo "Error in get_random(), one or more args are illegal or negative"
  fi
  # Use random var if it exists, othewise use uuid
  local MOD=$(($2-$1+1))
  local RAND
  if [ -n "$RANDOM" ]; then
    RAND="$RANDOM"
  else
    RAND="$(tr -cd '1-9' < /proc/sys/kernel/random/uuid | \
      head -c 1)$(tr -cd '0-9' < /proc/sys/kernel/random/uuid | head -c 4)"
  fi
  # Return random val
  echo "$((RAND % MOD + $1))"
}

# Check for max server number passed as arg $1
if [ -n "$1" ]; then 
  MAX_SERVERS="$1"
else
  # Select random number with uuid data
  MAX_SERVERS="$(get_random 4 9)"
fi

# Check for server list, generate one if missing
if [ -s "$IP_FILE" ]; then
  echo "Found ipv4 ntp server list, continuing with existing file: 
$IP_FILE"
elif [ -x "$GEN_SCR" ]; then
  echo "No existing ipv4 ntp server list found, generating one now:"
  source "$GEN_SCR"
  [ -s "$IP_FILE" ] || (echo "Error, generating server file failed"; exit 1)
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
  LINE="$(get_random 1 "$TOTAL_NUM_SERVERS")"
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
