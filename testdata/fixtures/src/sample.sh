#!/usr/bin/env bash
# sample.sh — comprehensive Bash syntax fixture for parser testing.
# Covers: variables, arrays, associative arrays, functions, arithmetic,
# string operations, control flow, loops, here-docs, process substitution,
# traps, subshells, pipes, redirections, getopts, regex, coprocesses.

set -euo pipefail
IFS=$'\n\t'

# --------------------------------------------------------------------------- #
# Constants & readonly variables
# --------------------------------------------------------------------------- #

readonly MAX_RETRIES=3
readonly DEFAULT_TIMEOUT=30
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${TMPDIR:-/tmp}/sample_$$.log"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'   # no color

# --------------------------------------------------------------------------- #
# Indexed arrays
# --------------------------------------------------------------------------- #

fruits=("apple" "banana" "cherry" "date")
nums=(1 2 3 4 5)

# Append
fruits+=("elderberry")

# Slicing
slice=("${fruits[@]:1:3}")   # banana cherry date

# Length
echo "Count: ${#fruits[@]}"

# --------------------------------------------------------------------------- #
# Associative arrays (Bash 4+)
# --------------------------------------------------------------------------- #

declare -A scores=(
  [alice]=95
  [bob]=87
  [carol]=92
)

scores[dave]=78

for name in "${!scores[@]}"; do
  printf "  %-10s %d\n" "$name" "${scores[$name]}"
done | sort

# --------------------------------------------------------------------------- #
# Functions
# --------------------------------------------------------------------------- #

log() {
  local level="$1"; shift
  local message="$*"
  local ts
  ts="$(date '+%Y-%m-%dT%H:%M:%S')"
  printf '[%s] [%s] %s\n' "$ts" "$level" "$message" | tee -a "$LOG_FILE" >&2
}

die() {
  log "ERROR" "$*"
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" &>/dev/null || die "Required command not found: $cmd"
}

# Function with default arguments
greet() {
  local name="${1:-World}"
  local greeting="${2:-Hello}"
  printf '%s, %s!\n' "$greeting" "$name"
}

# Function returning values via nameref (Bash 4.3+)
to_upper() {
  local -n _out_ref=$1
  _out_ref="${2^^}"
}

# Recursive function
factorial() {
  local n="$1"
  if (( n <= 1 )); then
    echo 1
  else
    echo $(( n * $(factorial $(( n - 1 ))) ))
  fi
}

# --------------------------------------------------------------------------- #
# Arithmetic
# --------------------------------------------------------------------------- #

x=10
y=3

sum=$(( x + y ))
diff=$(( x - y ))
prod=$(( x * y ))
quot=$(( x / y ))    # integer division
rem=$(( x % y ))
power=$(( x ** y ))

# Floating point via bc
pi=$(echo "scale=10; 4*a(1)" | bc -l)
area=$(echo "scale=4; 3.14159 * 5 * 5" | bc)

# --------------------------------------------------------------------------- #
# String operations
# --------------------------------------------------------------------------- #

str="  Hello, World!  "

trimmed="${str#"${str%%[! ]*}"}"      # ltrim
trimmed="${trimmed%"${trimmed##*[! ]}"}"   # rtrim
lower="${str,,}"
upper="${str^^}"
length=${#str}
substr="${str:2:5}"
replaced="${str/World/Bash}"
no_spaces="${str// /}"

# Regex matching
email="alice@example.com"
if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  echo "Valid email: $email"
fi

# --------------------------------------------------------------------------- #
# Control flow
# --------------------------------------------------------------------------- #

check_status() {
  local status="$1"
  case "$status" in
    pending)  echo "Waiting to start" ;;
    running)  echo "In progress"      ;;
    done)     echo "Completed"        ;;
    failed)   echo "Failed"           ;;
    *)        echo "Unknown: $status" ;;
  esac
}

# if / elif / else
classify_score() {
  local score="$1"
  if (( score >= 90 )); then
    echo "A"
  elif (( score >= 80 )); then
    echo "B"
  elif (( score >= 70 )); then
    echo "C"
  else
    echo "F"
  fi
}

# --------------------------------------------------------------------------- #
# Loops
# --------------------------------------------------------------------------- #

# C-style for
for (( i = 0; i < 5; i++ )); do
  printf "%d " "$i"
done; echo

# Range
for n in {1..5}; do printf "%d " "$n"; done; echo

# Array iteration
for fruit in "${fruits[@]}"; do
  echo "  - $fruit"
done

# While with counter
count=0
while (( count < MAX_RETRIES )); do
  (( count++ ))
done

# Until
i=10
until (( i <= 0 )); do
  (( i-- ))
done

# Read from file / process
while IFS= read -r line; do
  echo "Line: $line"
done < <(echo -e "one\ntwo\nthree")

# --------------------------------------------------------------------------- #
# Here-docs & here-strings
# --------------------------------------------------------------------------- #

cat <<'EOF'
This is a here-doc.
Variables like $HOME are NOT expanded.
EOF

cat <<EOF
Script dir: $SCRIPT_DIR
Timestamp: $(date)
EOF

grep -q "hello" <<< "hello world"

# --------------------------------------------------------------------------- #
# Process substitution & pipes
# --------------------------------------------------------------------------- #

diff <(echo "apple") <(echo "orange") || true

sorted_unique=$(printf '%s\n' "${fruits[@]}" | sort | uniq)

# Pipeline with xargs
echo "alice bob carol" | tr ' ' '\n' | xargs -I{} echo "Hello, {}!"

# --------------------------------------------------------------------------- #
# Subshells & command grouping
# --------------------------------------------------------------------------- #

(
  cd /tmp
  touch subshell_test_$$
  rm subshell_test_$$
)  # working dir unchanged outside

{ echo "grouped"; echo "commands"; } | cat

# --------------------------------------------------------------------------- #
# Redirections
# --------------------------------------------------------------------------- #

{
  echo "stdout"
  echo "stderr" >&2
} > /dev/null 2>&1

exec 3>&1          # save stdout to fd 3
exec 3>&-          # close fd 3

# --------------------------------------------------------------------------- #
# Traps & cleanup
# --------------------------------------------------------------------------- #

cleanup() {
  local exit_code=$?
  rm -f "$LOG_FILE"
  exit "$exit_code"
}

trap cleanup EXIT
trap 'die "Interrupted"' INT TERM

# --------------------------------------------------------------------------- #
# getopts argument parsing
# --------------------------------------------------------------------------- #

parse_args() {
  local OPTIND opt
  local verbose=0
  local output=""

  while getopts ":vo:" opt; do
    case "$opt" in
      v) verbose=1 ;;
      o) output="$OPTARG" ;;
      :) die "Option -$OPTARG requires an argument" ;;
      \?) die "Unknown option: -$OPTARG" ;;
    esac
  done
  shift $(( OPTIND - 1 ))

  if (( verbose )); then
    log "INFO" "verbose mode; output=$output; remaining args: $*"
  fi
}

# --------------------------------------------------------------------------- #
# Retry helper
# --------------------------------------------------------------------------- #

with_retry() {
  local max_attempts="$1"; shift
  local attempt=0
  until "$@"; do
    (( attempt++ ))
    if (( attempt >= max_attempts )); then
      die "Command failed after $max_attempts attempts: $*"
    fi
    sleep $(( 2 ** attempt ))
  done
}

# --------------------------------------------------------------------------- #
# Entry point
# --------------------------------------------------------------------------- #

main() {
  greet "Bash" "Hi"
  echo "Factorial 6 = $(factorial 6)"
  check_status "running"
  classify_score 87
  to_upper result_var "hello"
  echo "$result_var"
}

main "$@"
