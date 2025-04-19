#!/usr/bin/bash

# Default flag values
FILE=""
FILE_CONTENT=""
SINCE="30m"
KEY=""
REGEX=""
LEVEL=""
CONTAINS=""
JSON=false
HAS=""
FIELD=""
TOP=""
COUNT=false
PRETTY_PRINT=false
BAT_TOOL_INSTALLED=false
JQ_TOOL_INSTALLED=false
GREP_SUPPORTS_PCRE=false

if command -v bat &>/dev/null; then
  BAT_TOOL_INSTALLED=true
fi

if command -v jq &>/dev/null; then
  JQ_TOOL_INSTALLED=true
fi

if echo "test" | grep -P "t(?=e)" >/dev/null 2>&1; then
  GREP_SUPPORTS_PCRE=true
fi

# Log error to console and exit
log_error() {
  local message=$1
  printf "Error: %s\n" "$message"
  exit 1
}

# Show help text
show_help() {
  cat <<EOF
Usage: loggrep [OPTIONS]

A fast and flexible log filtering script for both plain text and JSON logs.

Input Options:
  -f, --file <path>         Path to the log file to read.
                            If omitted, input can be piped.

Time Filtering:
  --since <time>            Filter logs newer than given time.
                            Format: <number>[m|h|d|M|y]
                            (e.g., 30m, 2h, 1d). Default: 30m

General Text Filters:
  --level <value>           Case-insensitive match for log level (e.g., INFO, ERROR)
  --contains <string>       Case-insensitive substring match
  --regex <pattern>         Regular expression for filtering logs. Use [0-9] for digits.

JSON-Specific Filters (requires --json):
  --json                    Enables JSON parsing mode
  -k, --key <key>           Extract a specific key from each JSON log entry
  --has <key>               Only include logs that contain this key
  --field <k=v>             Filter logs where field matches key=value
                            (e.g., status=failed)

Output Controls:
  --top <n>                 Show only the first n matching lines
  --count                   Only print the number of matching lines
  --pretty                  Pretty-print the output (uses 'bat' for coloring)

Other:
  -h, --help                Show this help message

Examples:
  loggrep.sh -f server.log --level error --since 1h
  cat app.log | loggrep.sh --json --has userId --field status=failed
  loggrep.sh -f logs.txt --regex "[0-9]" --top 5
EOF
}

# Set value of flags to appropriate variable
set_flag() {
  local variable_name=$1
  local value=$2
  local argument=$3
  local boolean=$4

  if [[ -z "$boolean" && -n "$value" ]]; then
    if [[ $value = --* ]]; then
      log_error "$argument requires a value"
    fi

    declare -g "$variable_name"="$value"
  elif [[ ! -z "$boolean" && ("$boolean" == true || "$boolean" == false) ]]; then
    declare -g "$variable_name"="$boolean"
  else
    log_error "$argument requires a value"
  fi
}

validate_time() {
  local time_str="$1"

  if [[ "$time_str" =~ ^[0-9]+[mhdMy]$ ]]; then
    return 0
  fi

  log_error "Invalid time format [$time_str]. Only accepted in [m|h|d|M|y] (e.g. 1d,12m,3M)"
}

validate_field() {
  local input=$1

  if [[ "$input" =~ ^[a-zA-Z0-9_]+=[a-zA-Z0-9_]+$ ]]; then
    return 0
  fi

  log_error "invalid value passed to --field [$input]"
}

validate_flags() {

  if [[ -n "$FILE" ]]; then
    if [[ -f "$FILE" ]]; then
      FILE_CONTENT=$(cat "$FILE")
    else
      log_error "File [$FILE] not found"
    fi
  elif ! tty -s; then
    FILE_CONTENT=$(cat)
  else
    log_error "No input provided. Use --file or pipe input."
  fi

  if [[ -n "$HAS" ]]; then
    if [[ "$JSON" == "false" ]]; then
      log_error "--has only works when passed with --json flag"
    fi
  fi

  if [[ -n "$FIELD" ]]; then
    if [[ "$JSON" == "false" ]]; then
      log_error "--field only works when passed with --json flag"
    fi
  fi

  if [[ -n "$KEY" ]]; then
    if [[ "$JSON" == "false" ]]; then
      log_error "--key only works when passed with --json flag"
    fi
  fi

  validate_time "$SINCE"

  if [[ -n "$FIELD" ]]; then
    validate_field "$FIELD"
  fi

  if [[ -n "$TOP" ]]; then
    if [[ ! "$TOP" =~ ^[0-9]+$ ]]; then
      log_error "--top should be an integer"
    fi
  fi

  if [[ -n "$REGEX" ]]; then
    echo "test" | grep -E "$REGEX" >/dev/null 2>&1
    if [[ $? -eq 2 ]]; then
      log_error "Invalid regex pattern [$REGEX]"
    fi
  fi
}

parse_text_logs() {
  if [[ -z "$FILE_CONTENT" ]]; then
    echo "No logs"
    exit 0
  fi

  if [[ -n "$LEVEL" ]]; then
    FILE_CONTENT=$(grep -Ei "\[?$LEVEL\]?" <<<"$FILE_CONTENT")
  fi

  if [[ -n "$CONTAINS" ]]; then
    FILE_CONTENT=$(grep -i "$CONTAINS" <<<"$FILE_CONTENT")
  fi

  if [[ -n "$REGEX" ]]; then
    if [[ $GREP_SUPPORTS_PCRE == "true" ]]; then
      FILE_CONTENT=$(grep -Pi "$REGEX" <<<"$FILE_CONTENT")
    else
      FILE_CONTENT=$(grep -Ei "$REGEX" <<<"$FILE_CONTENT")
    fi
  fi

  local count=$(wc -l <<<"$FILE_CONTENT")

  if [[ -n "$TOP" ]]; then
    FILE_CONTENT=$(echo "$FILE_CONTENT" | head -n "$TOP")
  fi

  if [[ "$COUNT" == false ]]; then
    if [[ "$PRETTY_PRINT" == true ]]; then
      if [[ $BAT_COMMAND_INSTALLED == true ]]; then
        printf "\n%s" "$FILE_CONTENT" | bat --language=log --style=plain --color=always --paging=never
      else
        echo "The 'bat' command is not installed. It's required for pretty-printing"
        printf "\n%s" "$FILE_CONTENT"
      fi
    else
      printf "\n%s" "$FILE_CONTENT"
    fi

  else
    echo "$count"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -f | --file)
      set_flag "FILE" "$2" "$1"
      shift 2
      ;;
    --since)
      set_flag "SINCE" "$2" "$1"
      shift 2
      ;;
    -k | --key)
      set_flag "KEY" "$2" "$1"
      shift 2
      ;;
    --regex)
      set_flag "REGEX" "$2" "$1"
      shift 2
      ;;
    --level)
      set_flag "LEVEL" "$2" "$1"
      shift 2
      ;;
    --contains)
      set_flag "CONTAINS" "$2" "$1"
      shift 2
      ;;
    --json)
      set_flag "JSON" "" "$1" true
      shift
      ;;
    --has)
      set_flag "HAS" "$2" "$1"
      shift 2
      ;;
    --field)
      set_flag "FIELD" "$2" "$1"
      shift 2
      ;;
    --top)
      set_flag "TOP" "$2" "$1"
      shift 2
      ;;
    --count)
      set_flag "COUNT" "" "$1" true
      shift
      ;;
    --pretty)
      set_flag "PRETTY_PRINT" "" "$1" true
      shift
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    *)
      log_error "unknown option [$1]"
      shift
      ;;
    esac
  done
}

main() {
  parse_args "$@"

  validate_flags

  if [[ "$JSON" == false ]]; then
    parse_text_logs
  else
    echo "JSON parsing in progress"
  fi
}

main "$@"
