# LogGrep 🕵️📜

**LogGrep** is a lightweight and fast log filtering tool written in Bash. It helps you extract meaningful insights from log files whether plain text or JSON using flexible filtering options like time ranges, regex patterns, and structured field queries.

## Features ✨

- ⏱️ Time-based filtering (`--since 30m`, `--since 2h`)
- 🔍 Supports keyword, log level, and regex filtering
- 🗒️ JSON mode for structured logs (`--json`, `--field`, `--has`)
- 🗝️ Extract specific fields or keys
- 🔢 Count or limit the number of matching results
- 🎨 Pretty print using `bat` and `jq` (optional)
- ✅ Graceful validation and helpful error messages

## Installation 📦

No installation required. Just clone the repo and make the script executable:

```bash
git clone https://github.com/your-username/loggrep.git
cd loggrep
chmod +x loggrep.sh
```

Optionally move it to your PATH:

```bash
sudo mv loggrep.sh /usr/local/bin/loggrep
```

## Usage 🚀

```bash
loggrep [OPTIONS]
```

### Input Options 🗂️

- `-f, --file <path>` 
  Path to the log file to read. If omitted, input can be piped via standard input.

### Time Filtering ⏳

- `--since <duration>` 
  Filter logs newer than the given time. 
  Accepted formats: `<number>[m|h|d|M|y]` 
  Examples: `30m` (30 minutes), `2h` (2 hours), `1d` (1 day), `3M` (3 months), `1y` (1 year) 
  **Note**: Using the --since flag can slow down filtering, especially with large log files, as it requires processing each log entry's timestamp.
  
  **Note**: Currently, LogGrep only supports timestamps in **ISO 8601 format** (e.g., `2025-04-21T16:30:00`). Logs with different timestamp formats are not supported.

### General Text Filters 🧹

- `--level <value>` 
  Match log level (case-sensitive), e.g., `INFO`, `ERROR`, `DEBUG`
  **Works for both plain text and JSON logs**.

- `--contains <string>` 
  Case-insensitive substring match

- `--regex <pattern>` 
  Filter logs using a regular expression. 
  PCRE supported if your `grep` version allows it.

### JSON-Specific Filters 🪵➡️📊 (requires `--json`)

- `--json` 
  Enable JSON parsing mode

- `-k, --key <key>` 
  Extract a specific key from each JSON log entry

- `--has <key>` 
  Only include logs that contain this key

- `--field <k=v>` 
  Filter JSON logs where `key=value` 
  Example: `status=failed`

### Output Controls 📤

- `--top <n>` 
  Show only the first `n` matching lines

- `--count` 
  Print the number of matching lines instead of their content

- `--pretty` 
  Pretty-print the output (requires `bat`)

### Other 🛠️

- `-h, --help` 
  Show this help message

## Order of Operations ⚙️

LogGrep applies filters in the following order to optimize performance and ensure expected behavior:

1. **Text Filters**:
   
   - `--level`
   - `--contains`
   - `--regex`

2. **JSON Filters** (only if `--json` is used):
   
   - `--has`
   - `--field`
   - `--key`

3. **Time Filtering**:
   
   - `--since` (applied last to reduce overhead)

4. **Output Modifiers**:
   
   - `--top` (limits number of results)
   - `--count` (shows total count of all matches and overrides `--top`)

🛈 If both `--count` and `--top` are specified, `--count` takes precedence.

## Examples 🧪

```bash
# Filter logs with level ERROR in the last 1 hour
loggrep --file app.log --level error --since 1h

# Extract JSON logs that have 'userId' and status = failed
cat logs.json | loggrep --json --has userId --field status=failed

# Get top 5 entries matching a regex
loggrep -f system.log --regex "[0-9]{3}" --top 5

# Count matching lines from piped input
cat server.log | loggrep --contains timeout --count
```

## Upcoming Features 🛣️

- ~~Full JSON parsing with structured filtering~~~
- ~~Time-based filtering~~~
- Performance improvements for large datasets
