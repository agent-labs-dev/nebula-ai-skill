#!/bin/sh
# Thin, predictable wrapper around the nebula-ai CLI for agent use.
# Every data command emits one JSON value on stdout.
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
pinned_version=$(tr -d '[:space:]' <"$script_dir/../cli-version")

usage() {
    printf '%s\n' \
        "Usage:" \
        "  nebula.sh doctor" \
        "  nebula.sh install" \
        "  nebula.sh version" \
        "  nebula.sh workspaces" \
        "  nebula.sh agents [--workspace ID_OR_SLUG]" \
        "  nebula.sh integrations [--workspace ID_OR_SLUG]" \
        "  nebula.sh channels [--workspace ID_OR_SLUG]" \
        "  nebula.sh accounts [--workspace ID_OR_SLUG] AGENT" \
        "  nebula.sh messages [--workspace ID_OR_SLUG] [--limit N] THREAD_ID" \
        "  nebula.sh chat [--workspace ID_OR_SLUG] [--agent NAME_OR_SLUG | --thread THREAD_ID]" \
        "                 [--context GLOB]... -- MESSAGE" \
        "" \
        "Exit codes: 0 ok, 1 CLI error, 2 usage error, 3 not signed in (doctor), 127 missing dependency."
}

usage_error() {
    printf 'nebula.sh: %s\n' "$1" >&2
    usage >&2
    exit 2
}

require_cli() {
    if ! command -v nebula-ai >/dev/null 2>&1; then
        printf '%s\n' "nebula-ai is not installed. Run: npm install --global nebula-ai@$pinned_version" >&2
        exit 127
    fi
}

workspace=""
agent=""
thread=""
limit="50"
contexts=""
positional_count=0
positional=""

# Parse wrapper options. $1 lists the options the current command accepts.
parse_options() {
    allowed=$1
    shift
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --workspace|--agent|--thread|--limit|--context)
                case " $allowed " in *" $1 "*) ;; *) usage_error "unsupported option: $1" ;; esac
                if [ "$#" -lt 2 ] || [ -z "$2" ]; then usage_error "$1 requires a non-empty value"; fi
                case "$2" in *'
'*) usage_error "$1 value must not contain a newline" ;; esac
                case "$1" in
                    --workspace) workspace=$2 ;;
                    --agent) agent=$2 ;;
                    --thread) thread=$2 ;;
                    --limit) limit=$2 ;;
                    --context) contexts="$contexts$2
" ;;
                esac
                shift 2
                ;;
            --)
                shift
                break
                ;;
            -*)
                usage_error "unknown option: $1"
                ;;
            *)
                break
                ;;
        esac
    done
    positional_count=$#
    positional=${1:-}
    [ "$#" -le 1 ] || usage_error "expected one argument; quote the message"
}

run_cli() {
    if [ -n "$workspace" ]; then
        nebula-ai --workspace "$workspace" --json --no-color "$@"
    else
        nebula-ai --json --no-color "$@"
    fi
}

doctor() {
    require_cli
    installed=$(nebula-ai --version 2>/dev/null || true)
    printf 'nebula-ai: %s (skill verified against %s)\n' "${installed:-unknown}" "$pinned_version"
    if [ "$installed" != "$pinned_version" ]; then
        printf '%s\n' "warning: installed version differs from $pinned_version; commands or output may differ." >&2
    fi
    if status_json=$(nebula-ai --json --no-color status 2>/dev/null) &&
        printf '%s' "$status_json" | grep -Eq '"logged_in"[[:space:]]*:[[:space:]]*true'; then
        printf '%s\n' "auth: signed in"
    else
        printf '%s\n' "auth: not signed in. Run: nebula-ai login" >&2
        exit 3
    fi
}

command_name=${1:-}
[ -n "$command_name" ] || usage_error "missing command"
shift

case "$command_name" in
    doctor)
        [ "$#" -eq 0 ] || usage_error "doctor takes no arguments"
        doctor
        ;;
    install)
        [ "$#" -eq 0 ] || usage_error "install takes no arguments"
        command -v npm >/dev/null 2>&1 || {
            printf '%s\n' "npm is required to install nebula-ai" >&2
            exit 127
        }
        npm install --global "nebula-ai@$pinned_version"
        ;;
    version)
        [ "$#" -eq 0 ] || usage_error "version takes no arguments"
        printf '%s\n' "$pinned_version"
        ;;
    workspaces)
        [ "$#" -eq 0 ] || usage_error "workspaces takes no arguments"
        require_cli
        run_cli workspace list
        ;;
    agents|integrations|channels)
        parse_options "--workspace" "$@"
        [ "$positional_count" -eq 0 ] || usage_error "$command_name takes no arguments"
        require_cli
        run_cli "$command_name" list
        ;;
    accounts)
        parse_options "--workspace" "$@"
        if [ "$positional_count" -ne 1 ] || [ -z "$positional" ]; then usage_error "accounts requires AGENT"; fi
        require_cli
        run_cli agents accounts "$positional"
        ;;
    messages)
        parse_options "--workspace --limit" "$@"
        if [ "$positional_count" -ne 1 ] || [ -z "$positional" ]; then usage_error "messages requires THREAD_ID"; fi
        case "$limit" in '' | 0 | *[!0-9]*) usage_error "--limit must be a positive integer" ;; esac
        require_cli
        run_cli channels messages --limit "$limit" "$positional"
        ;;
    chat)
        parse_options "--workspace --agent --thread --context" "$@"
        if [ "$positional_count" -ne 1 ] || [ -z "$positional" ]; then usage_error "chat requires one MESSAGE after --"; fi
        [ -z "$agent" ] || [ -z "$thread" ] || usage_error "use --agent or --thread, not both"
        require_cli
        message=$positional
        set -- chat --no-stream
        [ -z "$agent" ] || set -- "$@" --agent "$agent"
        [ -z "$thread" ] || set -- "$@" --channel "$thread"
        if [ -n "$contexts" ]; then
            # Globs are passed through verbatim for the CLI to expand.
            set -f
            old_ifs=$IFS
            IFS='
'
            for pattern in $contexts; do
                set -- "$@" --context "$pattern"
            done
            IFS=$old_ifs
            set +f
        fi
        run_cli "$@" -- "$message"
        ;;
    -h|--help|help)
        [ "$#" -eq 0 ] || usage_error "$command_name takes no arguments"
        usage
        ;;
    *)
        usage_error "unknown command: $command_name"
        ;;
esac
