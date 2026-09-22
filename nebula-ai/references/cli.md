# nebula-ai CLI reference

Commands relevant to delegation in nebula-ai 0.1.9. Prefer `scripts/nebula.sh`
where it covers a task. For anything else, read the command's `--help` output
before running it.

## Install and sign in

```sh
npm install --global nebula-ai@0.1.9
nebula-ai --version
nebula-ai login
nebula-ai status
nebula-ai logout
```

`login` uses device pairing: the user opens a URL, confirms a code in the
browser, and the CLI stores the session in its own credential store. Never
collect authentication material in chat or save it in a project.

`nebula-ai update --check` reports whether a newer CLI exists without
installing it. Upgrading changes the user's machine and may move the CLI past
the version this skill was verified against; ask first.

## Global options

Place global options before the command.

| Option | Effect |
|---|---|
| `--json` | Machine-readable output where supported. See [json-output.md](json-output.md). |
| `--no-color` | Disable ANSI colors. |
| `--workspace <id-or-slug>` | Use this workspace. In 0.1.9 a valid value is also saved as the default, despite the help text saying per-session; an unknown value warns and falls back to the last-used workspace. |
| `--log-level <level>` | `error`, `warn`, `info`, `debug`, or `trace`, written to stderr. |

## Workspaces

```sh
nebula-ai --json workspace list
nebula-ai workspace switch <id-or-slug>
```

`workspace switch` changes the saved default for every later command. Ask
before switching.

## Agents

```sh
nebula-ai --json agents list
nebula-ai --json agents get <agent>
nebula-ai --json agents accounts <agent>
nebula-ai --json agents skills list <agent-id>
```

`agents get` and `agents accounts` accept an ID or slug. `chat --agent`
accepts an ID, a slug, or a case-insensitive name. Without `--agent`, chat uses
the first enabled, non-system agent.

`nebula-ai agents set-account <agent-id> --account <account-id>` chooses which
connected account an agent acts as. Only the agent's owner can do this, and it
changes what the agent can reach. Get explicit approval first.

## Chat

```sh
nebula-ai --json --no-color chat --no-stream --agent "<agent>" -- "<task>"
nebula-ai --json --no-color chat --no-stream --channel "<thread-id>" -- "<follow-up>"
nebula-ai --json --no-color chat --no-stream --agent "<agent>" --context "docs/*.md" -- "<task>"
```

| Option | Effect |
|---|---|
| `-a, --agent <agent>` | Send to this agent's direct-message thread. |
| `-c, --channel <thread-id>` | Send to an existing thread. Takes precedence over `--agent`. |
| `--context <glob>` | Upload matching files with the message. Repeatable. Quote the glob. At most 50 files and 512 KiB in total; a glob that matches nothing is an error. |
| `--no-stream` | Wait and print one result. Always use it for automation. |
| `-r, --resume <thread-id>` | Open the interactive terminal UI on a thread. For the user, not for automation; it cannot be combined with a message. |

Put `--` before the message so text beginning with `-` is not read as an
option.

## Threads

The CLI calls threads "channels": `channels` commands and the `--channel`
option take thread IDs.

```sh
nebula-ai --json channels list --limit 20
nebula-ai --json channels list --archived
nebula-ai --json channels get <thread-id>
nebula-ai --json channels status <thread-id>
nebula-ai --json channels messages --limit 50 <thread-id>
nebula-ai --json channels create --agent <agent-id> --title "<title>"
```

`channels status` reports the thread's current work status. `channels create`
starts a separate thread addressed to an agent; use it when unrelated work
should not share the agent's direct-message history.

## Integrations

```sh
nebula-ai --json integrations list
nebula-ai integrations connect <provider>
nebula-ai integrations disconnect <provider> [account-id]
```

`connect` starts an authorization flow the user completes in a browser.
Connecting or disconnecting changes external authorization and always requires
explicit approval. If a service is not offered here, ask the user to connect it
in Nebula rather than collecting credentials.

## Usage

```sh
nebula-ai --json usage --days 7
```

Reports workspace token usage and cost for 1 to 365 days (default 7).

## Exit codes and failures

| Situation | Behavior | Response |
|---|---|---|
| Wrapper usage error | Exit `2` | Fix the arguments. |
| CLI missing | Exit `127` | Offer `scripts/nebula.sh install`. |
| Not signed in | Wrapper `doctor` exits `3`; CLI commands exit `1` with a sign-in message on stderr | Run `nebula-ai login` and wait for the user. |
| `doctor` exits `1` | `status` failed for a reason other than sign-in; its error is on stderr | Report the error; do not start a login. |
| Unknown command or option | Exit `1`, `error: unknown ...` on stderr | Check `--help`; the installed CLI may differ from 0.1.9. |
| Agent not found | Exit `1` | Re-list agents; do not substitute another. |
| Run failed or incomplete | Exit `0`, `status` is `failed` or `incomplete` | See the result handling in SKILL.md. |
| Network or service error | Exit `1` | Report it once; do not loop. |

Errors are written to stderr as text, not JSON.
