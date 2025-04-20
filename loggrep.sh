#!/usr/bin/bash

# Default flag values
FILE=""
FILE_CONTENT=""
SINCE=""
SINCE_CUTOFF=""
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
BAT_INSTALLED=false
JQ_INSTALLED=false
AWK_INSTALLED=false
GREP_SUPPORTS_PCRE=false

if command -v bat &>/dev/null; then
  BAT_INSTALLED=true
fi

if command -v jq &>/dev/null; then
  JQ_INSTALLED=true
fi

if command -v awk &>/dev/null; then
  AWK_INSTALLED=true
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
                            **Note**: Using the --since flag can slow down filtering, 
                            especially with large log files, as it requires processing 
                            each log entry's timestamp.
                            **Note**: Only supports ISO 8601 timestamps (e.g., 2025-04-21T16:30:00)

General Text Filters:
  --level <value>           Case-sensitive match for log level (e.g., INFO, ERROR)
                            Works for both plain text and JSON logs.
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

parse_duration_to_epoch() {
  local input="$1"
  local num="${input//[!0-9]/}"
  local unit="${input: -1}"

  case "$unit" in
  m) date -d "$num minutes ago" +%s ;;
  h) date -d "$num hours ago" +%s ;;
  d) date -d "$num days ago" +%s ;;
  M) date -d "$num months ago" +%s ;;
  y) date -d "$num years ago" +%s ;;
  *) log_error "Invalid time unit in --since: $unit" ;;
  esac
}

filter_by_time() {
  local since_epoch="$1"

  FILE_CONTENT=$(awk -v since="$since_epoch" '
    {
      match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}:[0-9]{2}/, ts)
      if (ts[0] != "") {
        gsub("T", " ", ts[0])
        cmd = "date -d \"" ts[0] "\" +%s"
        cmd | getline log_epoch
        close(cmd)

        if (log_epoch >= since) {
          print $0
        }
      }
    }
  ' <<<"$FILE_CONTENT")
}

validate_field() {
  local input="$1"

  if [[ "$input" =~ ^[a-zA-Z0-9_]+=[a-zA-Z0-9_]+$ ]]; then
    return 0
  fi

  log_error "invalid value passed to --field [$input]"
}

get_key_value() {
  local input="$1"

  FIELD_KEY="${input%%=*}"
  FIELD_VALUE="${input#*=}"
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

  if [[ "$JSON" == true && "$JQ_INSTALLED" == false ]]; then
    log_error "loggrep uses jq to parse JSON logs. Please install jq to use the --json flag"
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

  if [[ -n "$SINCE" ]]; then
    if [[ "$AWK_INSTALLED" == true ]]; then
      validate_time "$SINCE"
      SINCE_CUTOFF=$(parse_duration_to_epoch "$SINCE")
    else
      log_error "loggrep uses awk for time-based filtering. Please install awk to use the --since flag"
    fi
  fi

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

  if [[ -n "$SINCE" && -n "$SINCE_CUTOFF" ]]; then
    filter_by_time "$SINCE_CUTOFF"
  fi

  local count=$(wc -l <<<"$FILE_CONTENT")

  if [[ -n "$TOP" ]]; then
    FILE_CONTENT=$(echo "$FILE_CONTENT" | head -n "$TOP")
  fi

  if [[ "$COUNT" == false ]]; then
    if [[ "$PRETTY_PRINT" == true ]]; then
      if [[ "$BAT_INSTALLED" == true ]]; then
        printf "\n%s" "$FILE_CONTENT" | bat --language=log --style=plain --color=always --paging=never
      else
        echo "The 'bat' tool is not installed. It's required for pretty-printing text logs"
        printf "\n%s" "$FILE_CONTENT"
      fi
    else
      printf "\n%s" "$FILE_CONTENT"
    fi

  else
    echo "$count"
  fi
}

parse_json_logs() {

  if [[ -n "$HAS" ]]; then
    FILE_CONTENT=$(echo "$FILE_CONTENT" | jq --arg key $HAS 'select(has($key))' -c -M)
  fi

  if [[ -n "$LEVEL" ]]; then
    FILE_CONTENT=$(echo "$FILE_CONTENT" | jq --arg level $LEVEL 'select(.level == $level or .LEVEL == $level or .L == $level)' -c -M)
  fi

  if [[ -n "$FIELD" ]]; then
    get_key_value "$FIELD"
    FILE_CONTENT=$(echo "$FILE_CONTENT" | jq --arg key $FIELD_KEY --arg value $FIELD_VALUE 'select(.[$key] == $value)' -c -M)
  fi

  if [[ -n "$SINCE" && -n "$SINCE_CUTOFF" ]]; then
    filter_by_time "$SINCE_CUTOFF"
  fi

  if [[ -n "$KEY" ]]; then
    FILE_CONTENT=$(echo "$FILE_CONTENT" | jq --arg key $KEY '.[$key]' -c -M)
  fi

  local count=$(wc -l <<<"$FILE_CONTENT")

  if [[ -n "$TOP" ]]; then
    FILE_CONTENT=$(echo "$FILE_CONTENT" | head -n $TOP)
  fi

  if [[ "$COUNT" == false ]]; then
    if [[ "$PRETTY_PRINT" == true ]]; then
      printf "%s" $FILE_CONTENT | jq '.'
    else
      printf "%s" $FILE_CONTENT | jq -c -M
    fi
  else
    printf "%s" "$count"
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

  if [[ -z "$FILE_CONTENT" ]]; then
    echo "No logs"
    exit 0
  fi

  if [[ "$JSON" == false ]]; then
    parse_text_logs
  else
    parse_json_logs
  fi
}

main "$@"
