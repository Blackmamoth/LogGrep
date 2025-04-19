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

generate_random_timestamp() {
  # Get current epoch and subtract up to 172800 seconds (2 days)
  OFFSET=$((RANDOM % 172800))
  RANDOM_EPOCH=$(($(date +%s) - OFFSET))
  date -d "@$RANDOM_EPOCH" '+%Y-%m-%d %H:%M:%S'
}

generate_iso_timestamp() {
  OFFSET=$((RANDOM % 172800))
  RANDOM_EPOCH=$(($(date +%s) - OFFSET))
  date -d "@$RANDOM_EPOCH" --iso-8601=seconds
}

while true; do
  TEXT_TIMESTAMP=$(generate_random_timestamp)
  ISO_TIMESTAMP=$(generate_iso_timestamp)
  LEVEL=${LOG_LEVELS[$RANDOM % ${#LOG_LEVELS[@]}]}
  MESSAGE=${MESSAGES[$RANDOM % ${#MESSAGES[@]}]}
  IP=$(generate_ip)

  echo "$TEXT_TIMESTAMP [$LEVEL] $MESSAGE from $IP" >>"$TEXT_LOG_FILE"
  echo "{\"timestamp\": \"$ISO_TIMESTAMP\", \"level\": \"$LEVEL\", \"message\": \"$MESSAGE\", \"ip\": \"$IP\"}" >>"$JSON_LOG_FILE"

  sleep 0.01 # Tune as needed
done
