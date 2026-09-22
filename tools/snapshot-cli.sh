#!/bin/sh
set -eu

usage() {
    printf '%s\n' 'Usage: tools/snapshot-cli.sh [--check]'
}

mode='write'
case $# in
    0) ;;
    1)
        case $1 in
            --check) mode=check ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; exit 2 ;;
        esac
        ;;
    *) usage >&2; exit 2 ;;
esac

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
pin=$(cat "$repo_dir/nebula-ai/cli-version")
task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [ -n "${NEBULA_AI_BIN:-}" ]; then
    cli_bin=$(command -v "$NEBULA_AI_BIN") || {
        printf 'Cannot find NEBULA_AI_BIN: %s\n' "$NEBULA_AI_BIN" >&2
        exit 1
    }
else
    npm install --prefix "$task_tmp/npm" --no-audit --no-fund "nebula-ai@$pin" >&2
    cli_bin=$task_tmp/npm/node_modules/.bin/nebula-ai
fi

python3 - "$cli_bin" "$pin" "$task_tmp/cli-surface.txt" <<'PY'
import os
from pathlib import Path
import re
import subprocess
import sys

binary, pin, destination = sys.argv[1:]
ansi = re.compile(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b\[[0-?]*[ -/]*[@-~]|\x1b[@-_]")
env = dict(os.environ, NO_COLOR="1", TERM="dumb", COLUMNS="80", LINES="24")
env.pop("FORCE_COLOR", None)


def invoke(*args):
    command = [binary, "--json", *args]
    try:
        result = subprocess.run(
            ["timeout", "30", *command], stdin=subprocess.DEVNULL,
            capture_output=True, text=True, env=env, check=False,
        )
    except OSError as exc:
        raise SystemExit(f"Cannot run {' '.join(command)}: {exc}") from exc
    if result.returncode:
        reason = "timed out after 30 seconds" if result.returncode == 124 else f"exited {result.returncode}"
        raise SystemExit(f"{' '.join(command)}: {reason}\n{result.stderr}{result.stdout}")
    return "\n".join(line.rstrip() for line in ansi.sub("", result.stdout).splitlines()).strip("\n")


version = invoke("--version")
if version != pin:
    raise SystemExit(f"CLI version mismatch: expected {pin}, got {version!r}")


def walk(path, output):
    help_text = invoke(*path, "--help")
    if not help_text.startswith("Usage:"):
        raise SystemExit(f"Invalid help for nebula-ai {' '.join(path)}: missing Usage section")
    output.write("\n===== nebula-ai" + (" " + " ".join(path) if path else "") + "\n")
    output.write(help_text + "\n")
    in_commands = False
    for line in help_text.splitlines():
        if line == "Commands:":
            in_commands = True
        elif line and not line[0].isspace():
            in_commands = False
        elif in_commands:
            match = re.match(r"^  ([a-zA-Z0-9][a-zA-Z0-9-]*)(?:\s|$)", line)
            if match and match[1] != "help":
                walk((*path, match[1]), output)


with Path(destination).open("w", encoding="utf-8", newline="\n") as output:
    output.write(f"# nebula-ai {pin}\n")
    walk((), output)
PY

snapshot=$repo_dir/tests/cli-surface.txt
if [ "$mode" = check ]; then
    if [ ! -f "$snapshot" ]; then
        printf '%s\n' 'Missing tests/cli-surface.txt; run tools/snapshot-cli.sh.' >&2
        exit 1
    fi
    if ! diff -u "$snapshot" "$task_tmp/cli-surface.txt"; then
        printf '%s\n' 'CLI surface differs; run tools/snapshot-cli.sh and review the changes.' >&2
        exit 1
    fi
    printf 'CLI surface matches nebula-ai %s.\n' "$pin"
else
    mkdir -p "$repo_dir/tests"
    cp "$task_tmp/cli-surface.txt" "$snapshot"
    printf 'Wrote tests/cli-surface.txt for nebula-ai %s.\n' "$pin"
fi
