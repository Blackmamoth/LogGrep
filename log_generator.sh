#!/bin/bash

TEXT_LOG_FILE="text_logs.log"
JSON_LOG_FILE="json_logs.log"

LOG_LEVELS=("INFO" "WARN" "ERROR" "DEBUG")
MESSAGES=(
  "User logged in"
  "User logged out"
  "Database connection established"
  "Database connection lost"
  "File not found"
  "Access denied"
  "Internal server error"
  "Request timeout"
)

generate_ip() {
  echo "$((RANDOM % 256)).$((RANDOM % 256)).$((RANDOM % 256)).$((RANDOM % 256))"
}

generate_timestamp() {
  OFFSET=$((RANDOM % 172800)) # Up to 2 days ago
  RANDOM_EPOCH=$(($(date +%s) - OFFSET))
  date -d "@$RANDOM_EPOCH" '+%Y-%m-%d %H:%M:%S'
}

I=0

while true; do
  TIMESTAMP=$(generate_timestamp)
  LEVEL=${LOG_LEVELS[$RANDOM % ${#LOG_LEVELS[@]}]}
  MESSAGE=${MESSAGES[$RANDOM % ${#MESSAGES[@]}]}
  IP=$(generate_ip)

  # Text log (if needed)
  echo "$TIMESTAMP [$LEVEL] $MESSAGE from $IP" >>"$TEXT_LOG_FILE"

  # JSON logs with supported timestamp
  echo "{\"timestamp\": \"$TIMESTAMP\", \"level\": \"$LEVEL\", \"message\": \"$MESSAGE\", \"ip\": \"$IP\"}" >>"$JSON_LOG_FILE"

  sleep 0.01
done
