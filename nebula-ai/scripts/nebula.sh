#!/bin/sh
set -eu

usage() {
    printf '%s\n' \
        "Usage:" \
        "  nebula.sh doctor" \
        "  nebula.sh install" \
        "  nebula.sh agents [--workspace ID_OR_SLUG]" \
        "  nebula.sh integrations [--workspace ID_OR_SLUG]" \
        "  nebula.sh channels [--workspace ID_OR_SLUG]" \
        "  nebula.sh chat [--workspace ID_OR_SLUG] [--agent NAME_OR_SLUG] -- MESSAGE"
}

require_cli() {
    if ! command -v nebula-ai >/dev/null 2>&1; then
        printf '%s\n' "nebula-ai is not installed. Run: npm install --global nebula-ai" >&2
        exit 127
    fi
}

workspace=""
agent=""

parse_options() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --workspace)
                [ "$#" -ge 2 ] || { printf '%s\n' "--workspace requires a value" >&2; exit 2; }
                workspace=$2
                shift 2
                ;;
            --agent)
                [ "$#" -ge 2 ] || { printf '%s\n' "--agent requires a value" >&2; exit 2; }
                agent=$2
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                break
                ;;
        esac
    done
    remaining_count=$#
    if [ "$remaining_count" -gt 0 ]; then
        message=$1
        shift
        [ "$#" -eq 0 ] || { printf '%s\n' "message must be one quoted argument" >&2; exit 2; }
    else
        message=""
    fi
}

run_with_workspace() {
    if [ -n "$workspace" ]; then
        nebula-ai --workspace "$workspace" "$@"
    else
        nebula-ai "$@"
    fi
}

command_name=${1:-}
[ -n "$command_name" ] || { usage >&2; exit 2; }
shift

case "$command_name" in
    doctor)
        require_cli
        nebula-ai --version
        nebula-ai --no-color status
        ;;
    install)
        command -v npm >/dev/null 2>&1 || {
            printf '%s\n' "npm is required to install nebula-ai" >&2
            exit 127
        }
        npm install --global nebula-ai
        ;;
    agents|integrations|channels)
        require_cli
        parse_options "$@"
        [ "$remaining_count" -eq 0 ] || { usage >&2; exit 2; }
        run_with_workspace --json "$command_name" list
        ;;
    chat)
        require_cli
        parse_options "$@"
        [ "$remaining_count" -eq 1 ] && [ -n "$message" ] || { usage >&2; exit 2; }
        if [ -n "$agent" ]; then
            run_with_workspace --json --no-color chat --no-stream --agent "$agent" "$message"
        else
            run_with_workspace --json --no-color chat --no-stream "$message"
        fi
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        printf '%s\n' "Unknown command: $command_name" >&2
        usage >&2
        exit 2
        ;;
esac
