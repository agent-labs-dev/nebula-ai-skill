# nebula-ai CLI reference

Commands relevant to delegation in nebula-ai 0.1.41. For anything else, read
the command's `--help` output before running it.

## Install and sign in

```sh
npm install --global nebula-ai@0.1.41
nebula-ai --version
nebula-ai login
nebula-ai status
nebula-ai logout
```

`login` uses device pairing: the user opens a URL, confirms a code in the
browser, and the CLI stores the session in its own credential store. Never
collect authentication material in chat or save it in a project.

`logout` signs out the current account. `nebula-ai logout --all` signs out
every account on the backend. Both change the user's machine; ask first.

`nebula-ai update --check` reports whether a newer CLI exists without
installing it. Upgrading changes the user's machine and may move the CLI past
the version this skill was verified against; ask first.

## Global options

Place global options before the command.

| Option | Effect |
|---|---|
| `--json` | Machine-readable output where supported. See [json-output.md](json-output.md). |
| `--no-color` | Disable ANSI colors. |
| `--workspace <id-slug-or-name>` | Use this workspace for one command. An unknown or ambiguous value stops the command with a `usage` error (exit `2`), before anything is read or written, and does not change the saved default. |
| `--log-level <level>` | `error`, `warn`, `info`, `debug`, or `trace`, written to stderr. |

## Workspaces and accounts

```sh
nebula-ai --json workspace list
nebula-ai workspace switch <id-slug-or-name>
nebula-ai --json account list
nebula-ai account switch <email-or-user-id>
```

`workspace list` includes every signed-in account's workspaces; an entry may
also carry an `account`. `workspace switch` changes the saved default for
every later command; ask before switching. An unknown workspace is a `usage`
error, not a fallback.

`account switch` chooses the account used for account-level commands and for
creating a workspace. Ask before switching accounts. The current account's
workspaces remain available through `workspace list`.

## Agents

```sh
nebula-ai --json agents list
nebula-ai --json agents list --runnable --query "<text>"
nebula-ai --json agents get <agent>
nebula-ai --json agents skills list <agent-id>
```

`agents list` accepts `--limit`, `--query` (name or handle), and `--runnable`
(only agents you can run). `agents get` accepts an ID or handle.
`chat --agent` accepts a name, handle, or ID. Without `--agent`, chat uses the
first enabled, non-system agent that does not lead Channels.

The workspace's own `Nebula` agent is the Home assistant. Naming it sends
`chat` to Home rather than to an agent DM; it does not run a Task. Use it only
when the user wants to talk to Nebula itself.

`toolkits` in the listing names the services an agent can use. Agents act
through the connected accounts of the person requesting work, and the CLI
cannot list or connect those accounts. If one is missing, ask the user to
connect it in Nebula.

## Chat

```sh
nebula-ai --json --no-color chat --no-stream --agent "<agent>" -- "<task>"
nebula-ai --json --no-color chat --no-stream --task "<thread-id>" -- "<follow-up>"
nebula-ai --json --no-color chat --no-stream --new --agent "<agent>" -- "<task>"
nebula-ai --json --no-color chat --no-stream --agent "<agent>" --context "docs/*.md" -- "<task>"
```

| Option | Effect |
|---|---|
| `-a, --agent <agent>` | Send to this agent: a name, handle, or ID. |
| `-t, --task <thread-id>` | Send to an existing thread. Takes precedence over `--agent`. |
| `--new` | Start a new chat with the agent instead of reusing its direct-message thread. Cannot be combined with `--task`; a usage error for the Home Nebula. |
| `--context <glob>` | Upload matching files with the message. Repeatable. Quote the glob. At most 50 files and 512 KiB in total; a glob that matches nothing is an error. |
| `--no-stream` | Wait and print one result. Always use it for automation. |
| `-r, --resume <thread-id>` | Open the interactive terminal UI on a thread. For the user, not for automation; it cannot be combined with a message. |

Put `--` before the message so text beginning with `-` is not read as an
option.

## Threads

The CLI calls agent conversations Tasks. `tasks` commands, `--task`, and
`messages list --task` take the `thread_id` returned by `chat`.

```sh
nebula-ai --json tasks list --limit 20
nebula-ai --json tasks list --mine
nebula-ai --json tasks list --channel <channel>
nebula-ai --json tasks get <thread-id>
nebula-ai --json tasks wait <thread-id>
nebula-ai --json messages list --task <thread-id> --limit 50
nebula-ai --json tasks create --agent <agent-handle> -- "<task>"
```

`tasks list` shows the Tasks you can see; `--mine` limits it to Tasks you own
or participate in, and `--channel` accepts a name or ID.

`tasks get` shows a Task's title, Channel, agent, and work status.
`messages list --task` prints the most recent messages, oldest first.
`tasks wait` blocks until the newest turn on a Task finishes and prints the
same result object and exit codes as `chat`.

`tasks create` starts a separate Task for an agent, when unrelated work should
not share the agent's direct-message history. `--agent` is required. It sends
`<task>` to the agent like `chat` does, so the same approval rules apply, but
it does not wait for the reply. The Task starts in Home unless
`--channel <channel>` names another Channel, and the agent must be on that
Channel's roster. Continue it with `chat --task`, or wait for its first turn
with `tasks wait`.

## Approvals

```sh
nebula-ai --json approvals list
```

`approvals list` shows the asks agents are waiting on you for, with `id`,
`task_id`, `task`, `agent`, `kind`, `title`, `summary`, and `created_at`. It is
read-only. The user decides what to approve; never run `approvals approve` or
`approvals deny` for them. An ask that needs more than a yes or no must be
answered in Nebula.

## Exit codes and failures

| Situation | Behavior | Response |
|---|---|---|
| CLI missing | The shell reports `command not found` (exit `127`) | Ask, then install the verified version. |
| Not signed in | Exit `3`; `status` prints `auth.logged_in` false, other commands print an `auth_required` error | Run `nebula-ai login` and wait for the user. A network failure is not a sign-out. |
| Unknown command or option | Exit `2`, `usage` error | Check `--help`; the installed CLI may differ from 0.1.41. |
| Unknown or ambiguous `--workspace` | Exit `2`, `usage` error listing the account's workspaces; nothing read or written | Fix the name; do not substitute another workspace. |
| `agents get` or `tasks get` not found | Exit `6`, `not_found` error | Re-list agents or Tasks; do not substitute another. |
| Unknown agent in `chat` | Exit `1`, `error`, nothing sent | Re-list agents; do not substitute another. |
| Run failed | Exit `1`, JSON printed with `status` `failed` | Report it once. |
| Run waiting for the user | Exit `4`, JSON printed with `status` `waiting` and `pending` | See the result handling in SKILL.md. |
| Chat waited 15 minutes or was interrupted | Exit `5`; JSON printed with `status` `incomplete` when a turn had started | Check `tasks get`; do not resend. |
| Chat reply unreadable, or a write got no answer in 30 seconds | Exit `5`, `outcome_unknown` error | Read the thread with `messages list --task`; do not resend. |
| A read got no answer in 30 seconds | Exit `7`, `timeout` error | Try once more, then report it. |
| Network or service error | Exit `1`, or `7` when Nebula did not answer in time | Report it once; do not loop. |

With `--json`, each failure prints exactly one line on stderr,
`{"error":{"code":"...","message":"...","trace_id":"..."}}`. `code` is
`error`, `usage` (exit `2`), `auth_required` (exit `3`), `waiting` (exit `4`),
`outcome_unknown` (exit `5`), `not_found` (exit `6`), or `timeout` (exit `7`).
`usage` errors omit `trace_id`; every other failure includes it. Without
`--json`, errors are plain text, with a `Trace:` line for the same failures.
