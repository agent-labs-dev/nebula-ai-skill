#!/bin/sh
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
wrapper=$repo_dir/nebula-ai/scripts/nebula.sh
pin=$(cat "$repo_dir/nebula-ai/cli-version")
task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "$task_tmp/bin" "$task_tmp/missing"
shell_bin=$(command -v sh)
original_path=$PATH
export SHIM_ARGV_LOG="$repo_dir/tests/.wrapper-argv.log"
export SHIM_CASE_LOG="$task_tmp/argv"
export SHIM_NPM_LOG="$task_tmp/npm-argv"
export SHIM_PIN="$pin"
export SHIM_LOGGED_OUT=0 SHIM_AUTH_FALSE=0 SHIM_VERSION="$pin" SHIM_EXIT_CODE=0
: > "$SHIM_ARGV_LOG"

cat > "$task_tmp/bin/nebula-ai" <<'SH'
#!/bin/sh
set -eu
log_args() {
    destination=$1
    shift
    separator=''
    for argument do
        printf '%s%s' "$separator" "$argument" >> "$destination"
        separator=$(printf '\037')
    done
    printf '\n' >> "$destination"
}
log_args "$SHIM_ARGV_LOG" "$@"
log_args "$SHIM_CASE_LOG" "$@"
last_argument=''
for last_argument do :; done
if [ "$#" -eq 1 ] && [ "$1" = --version ]; then
    printf '%s\n' "${SHIM_VERSION:-$SHIM_PIN}"
elif [ "$last_argument" = status ]; then
    if [ "${SHIM_LOGGED_OUT:-0}" = 1 ]; then
        printf '%s\n' 'Not signed in. Run nebula-ai login.' >&2
        exit 1
    fi
    logged_in=true
    if [ "${SHIM_AUTH_FALSE:-0}" = 1 ]; then logged_in=false; fi
    printf '{"auth":{"logged_in":%s,"email":null,"wallet_address":null},"daemon":null,"paths":{}}\n' "$logged_in"
else
    printf '%s\n' '[]'
    exit "${SHIM_EXIT_CODE:-0}"
fi
SH
cat > "$task_tmp/bin/npm" <<'SH'
#!/bin/sh
set -eu
separator=''
for argument do
    printf '%s%s' "$separator" "$argument" >> "$SHIM_NPM_LOG"
    separator=$(printf '\037')
done
printf '\n' >> "$SHIM_NPM_LOG"
SH
chmod +x "$task_tmp/bin/nebula-ai" "$task_tmp/bin/npm"

# The missing-CLI cases retain shell utilities without reaching the real CLI.
for utility in cat dirname basename sed grep awk tr head cut readlink realpath python3 jq; do
    utility_bin=$(command -v "$utility" || :)
    if [ -n "$utility_bin" ]; then
        ln -s "$utility_bin" "$task_tmp/missing/$utility"
    fi
done
export PATH="$task_tmp/bin:$original_path"
case_path=$PATH
failures=0
cases=0

expected() {
    separator=''
    for argument do
        printf '%s%s' "$separator" "$argument" >> "$task_tmp/expected"
        separator=$(printf '\037')
    done
    printf '\n' >> "$task_tmp/expected"
}

fail() {
    printf 'FAIL %s: %s\n' "$case_name" "$1" >&2
    failures=$((failures + 1))
}

run_case() {
    case_name=$1
    wanted_exit=$2
    shift 2
    cases=$((cases + 1))
    : > "$SHIM_CASE_LOG"
    : > "$SHIM_NPM_LOG"
    actual_exit=0
    PATH=$case_path "$shell_bin" "$wrapper" "$@" > "$task_tmp/stdout" 2> "$task_tmp/stderr" || actual_exit=$?
    if [ "$actual_exit" -ne "$wanted_exit" ]; then
        fail "expected exit $wanted_exit, got $actual_exit"
        cat "$task_tmp/stderr" >&2
    fi
    if ! diff -u "$task_tmp/expected" "$SHIM_CASE_LOG" > "$task_tmp/diff"; then
        fail 'CLI argv differs (unit separators shown as |)'
        tr '\037' '|' < "$task_tmp/diff" >&2
    fi
    : > "$task_tmp/expected"
}

: > "$task_tmp/expected"
expected --version
expected --json --no-color status
run_case 'doctor signed in' 0 doctor

SHIM_LOGGED_OUT=1
expected --version
expected --json --no-color status
run_case 'doctor status fails' 3 doctor
SHIM_LOGGED_OUT=0

SHIM_AUTH_FALSE=1
expected --version
expected --json --no-color status
run_case 'doctor logged_in false' 3 doctor
SHIM_AUTH_FALSE=0

SHIM_VERSION=0.0.0
expected --version
expected --json --no-color status
run_case 'doctor version warning' 0 doctor
if ! cat "$task_tmp/stdout" "$task_tmp/stderr" | grep -Eiq 'warn|mismatch|different|expected|supported'; then
    fail 'missing version warning'
fi
SHIM_VERSION=$pin

run_case install 0 install
expected install --global "nebula-ai@$pin"
if ! diff -u "$task_tmp/expected" "$SHIM_NPM_LOG"; then
    fail 'npm argv differs'
fi
: > "$task_tmp/expected"

for command_name in agents integrations channels; do
    expected --json --no-color "$command_name" list
    run_case "$command_name default" 0 "$command_name"
    expected --workspace 'team space' --json --no-color "$command_name" list
    run_case "$command_name workspace" 0 "$command_name" --workspace 'team space'
done
expected --json --no-color workspace list
run_case workspaces 0 workspaces
expected --json --no-color agents accounts 'agent id'
run_case 'accounts default' 0 accounts 'agent id'
expected --workspace team --json --no-color agents accounts agent
run_case 'accounts workspace' 0 accounts --workspace team agent
expected --json --no-color channels messages --limit 50 thread
run_case 'messages default limit' 0 messages thread
expected --workspace team --json --no-color channels messages --limit 7 thread
run_case 'messages explicit limit' 0 messages --workspace team --limit 7 thread
expected --json --no-color chat --no-stream -- 'hello world'
run_case 'chat default' 0 chat -- 'hello world'
expected --workspace team --json --no-color chat --no-stream --agent agent --context '*.md' --context 'docs with spaces/*' -- 'hello world'
run_case 'chat agent and repeated contexts' 0 chat --workspace team --agent agent --context '*.md' --context 'docs with spaces/*' -- 'hello world'
expected --json --no-color chat --no-stream --channel thread -- '-message starts with dash'
run_case 'chat thread and dash message' 0 chat --thread thread -- '-message starts with dash'
# shellcheck disable=SC2016
literal_message='literal $value; `command` "quotes"'
expected --json --no-color chat --no-stream -- "$literal_message"
run_case 'chat literal punctuation' 0 chat -- "$literal_message"
SHIM_EXIT_CODE=9
expected --json --no-color agents list
run_case 'CLI failure propagation' 9 agents
SHIM_EXIT_CODE=0

run_case version 0 version
printf '%s\n' "$pin" > "$task_tmp/version"
if ! diff -u "$task_tmp/version" "$task_tmp/stdout"; then fail 'version output differs'; fi
for command_name in help -h --help; do
    run_case "$command_name usage" 0 "$command_name"
    if ! grep -qi usage "$task_tmp/stdout"; then fail 'missing usage output'; fi
done

run_case 'no command' 2
run_case 'unknown command' 2 unknown
for command_name in doctor install workspaces version help -h --help; do
    run_case "$command_name extra argument" 2 "$command_name" extra
    run_case "$command_name unknown option" 2 "$command_name" --unknown
done
for command_name in agents integrations channels accounts messages chat; do
    run_case "$command_name unknown option" 2 "$command_name" --unknown
    run_case "$command_name workspace missing value" 2 "$command_name" --workspace
done
for command_name in agents integrations channels; do
    run_case "$command_name extra argument" 2 "$command_name" extra
done
run_case 'accounts missing agent' 2 accounts
run_case 'accounts extra argument' 2 accounts agent extra
run_case 'messages missing thread' 2 messages
run_case 'messages extra argument' 2 messages thread extra
run_case 'messages limit missing value' 2 messages --limit
run_case 'chat agent missing value' 2 chat --agent
run_case 'chat thread missing value' 2 chat --thread
run_case 'chat context missing value' 2 chat --context
run_case 'chat empty thread' 2 chat --thread '' -- message
run_case 'chat empty agent' 2 chat --agent '' -- message
newline_glob='report
secret.txt'
run_case 'chat newline context' 2 chat --context "$newline_glob" -- message
run_case 'chat agent and thread conflict' 2 chat --agent agent --thread thread -- message
expected --json --no-color chat --no-stream -- message
run_case 'chat without separator' 0 chat message
run_case 'chat dash message without separator' 2 chat -message
run_case 'chat missing message' 2 chat --
run_case 'chat extra message' 2 chat -- first second

case_path=$task_tmp/missing
for command_name in doctor agents integrations channels workspaces; do
    run_case "$command_name CLI absent" 127 "$command_name"
done
run_case 'accounts CLI absent' 127 accounts agent
run_case 'messages CLI absent' 127 messages thread
run_case 'chat CLI absent' 127 chat -- message
run_case 'install npm absent' 127 install
run_case 'version CLI absent' 0 version
run_case 'help CLI absent' 0 help

printf 'Wrapper tests: %s cases, %s failures.\n' "$cases" "$failures"
[ "$failures" -eq 0 ]
