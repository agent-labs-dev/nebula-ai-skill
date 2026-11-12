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
| `--workspace <id-slug-or-name>` | Use this workspace for one command. An unknown or ambiguous value stops the command with a `usage` error (exit `2`) listing the account's workspaces, before anything is read or written, and does not change the saved default. |
| `--log-level <level>` | `error`, `warn`, `info`, `debug`, or `trace`, written to stderr. |

## Workspaces and accounts

```sh
nebula-ai --json workspace list
nebula-ai workspace switch <id-or-slug>
nebula-ai --json account list
nebula-ai account switch <email-or-user-id>
```

`workspace list` includes every signed-in account's workspaces; an entry may
also carry an `account`. `workspace switch` takes an ID or slug and changes the
saved default for every later command; ask before switching. An unknown
workspace is a `usage` error, not a fallback.

`account switch` chooses the account used for account-level commands and for
creating a workspace. Ask before switching accounts. The current account's
workspaces remain available through `workspace list`.

## Agents

```sh
nebula-ai --json agents list
nebula-ai --json agents list | jq '.[] | {handle, name, description, toolkits, can_run, run_blocked_detail, is_disabled}'
nebula-ai --json agents list --query <text>
nebula-ai --json agents get <agent>
nebula-ai --json agents skills list <agent-id>
```

`agents list` prints every agent, which runs to hundreds of kilobytes on a
large workspace; project the fields you need with `jq`. `--query <text>`
keeps agents whose name or handle contains the text, `--runnable` only those
you can run, and `--limit <n>` caps the count.

How each command finds an agent:

| Command | Accepts | Searches |
|---|---|---|
| `agents get` | ID or handle | Every agent |
| `tasks create -a` | Handle only; an ID or name is refused | The Channel's roster |
| `chat --agent` | ID, handle, or case-insensitive name | Every agent you can read; another Channel lead is refused before sending |

The workspace's own `Nebula` agent is the Home assistant. Naming it sends
`chat` to Home rather than to an agent DM; it runs no Task. Use it only when
the user wants to talk to Nebula itself.

Without `--agent`, chat uses the first enabled, non-system agent.

`toolkits` in the listing names the services an agent can use. Agents act
through the connected accounts of the person requesting work, and the CLI
cannot list or connect those accounts. If one is missing, ask the user to
connect it in Nebula.

## Chat

```sh
nebula-ai --json --no-color chat --no-stream --task "<thread-id>" -- "<follow-up>"
nebula-ai --json --no-color chat --no-stream --new --agent "<agent>" -- "<task>"
nebula-ai --json --no-color chat --no-stream --agent "<agent>" --context "docs/*.md" -- "<task>"
```

| Option | Effect |
|---|---|
| `-a, --agent <agent>` | Send to this agent's direct-message thread, or to Home for the workspace's own Nebula: an ID, handle, or name. Every request sent to an agent this way shares one thread and keeps its first title, so start unrelated work with `tasks create`. |
| `--new` | With `--agent`, start a new private thread with the agent instead of its direct-message thread. Cannot be combined with `--task`; a `usage` error for the Home Nebula. |
| `-t, --task <thread-id>` | Send to an existing thread. Takes precedence over `--agent`. |
| `--context <glob>` | Upload matching files with the message. Repeatable. Quote the glob. At most 50 files and 512 KiB in total; a glob that matches nothing is an error. |
| `--no-stream` | Wait, for up to 15 minutes, and print one result. Always use it for automation; run it in the background when your tool calls are capped below 15 minutes. |
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
nebula-ai --json tasks create -a <agent-handle> -- "<task>"
```

`tasks list` returns 20 Tasks unless `--limit` asks for more. It draws from
every Task you can see in the workspace, including other members' Tasks:
active and unread Tasks come first, then the rest, newest first. `--mine`
keeps only Tasks you own or take part in. `tasks get` shows a Task's title,
Channel, agent, and `phase`; an archived or dismissed Task is `not_found`.
`tasks wait` blocks on the Task's newest turn for up to 15 minutes and
prints the `chat --no-stream` result with its exit codes; when the Task opens
no turn within 15 seconds it exits `5` and prints nothing.
`messages list --task` prints the most recent messages, oldest first.

`tasks create` is the way to start new work. It sends `<task>` to the agent
like `chat` does, so the same approval rules apply, but it returns once the
message is sent instead of waiting for the reply; poll `tasks get` on
`phase` and read the reply with `messages list --task`. `-a` is required and
takes a handle only. The Task starts in Home unless `--channel <channel>`
names another Channel by handle or ID, and the agent must be on that
Channel's roster. It cannot attach files. Continue it with `chat --task`.

## Approvals

```sh
nebula-ai --json approvals list
nebula-ai --json approvals approve <id>
nebula-ai --json approvals deny <id> --reason "<why>"
```

`approvals list` prints the asks agents are waiting on you for, newest
first. `approve` and `deny` answer one of them by its `id`, and only write
and plan approvals; any other ask is answered in the Nebula app.
`approve --always` allows that action on this device from now on. Run `approve` or
`deny` only on the user's explicit decision for that ask, never on their
behalf.

## Exit codes and failures

| Situation | Behavior | Response |
|---|---|---|
| CLI missing | The shell reports `command not found` (exit `127`) | Ask, then install the verified version. |
| Not signed in | Exit `3`; `status` prints `auth.logged_in` false, other commands print an `auth_required` error | Run `nebula-ai login` and wait for the user. |
| Unknown command, option, or unknown or ambiguous `--workspace` | Exit `2`, `usage` error; nothing read or written | Check `--help`, or fix the workspace without substituting another; the installed CLI may differ from 0.1.41. |
| Task, message or `agents get` target not found | Exit `6`, `not_found` error, nothing sent | Re-list agents or Tasks; do not substitute another. |
| `chat --agent` names no agent | Exit `1`, `error`, nothing sent | Re-list agents; do not substitute another. |
| Run failed | Exit `1`, JSON printed with `status` `failed` | Report it once. |
| Run waiting for the user | Exit `4`, JSON printed with `status` `waiting` and `pending` | See the result handling in SKILL.md. |
| `chat` or `tasks wait` waited 15 minutes or was interrupted | Exit `5`, JSON printed with `status` `incomplete` | Poll `tasks get` on `phase`; do not resend. |
| Chat reply unreadable, or a write got no answer in 30 seconds | Exit `5`, `outcome_unknown` error | Read the thread with `messages list --task`; do not resend. |
| A read got no answer in 30 seconds | Exit `7`, `timeout` error | Try once more. If it repeats, check for an exported `NEBULA_ZERO_CACHE_URL` and retry with it unset. Then report it. |
| Sync unreachable | Exit `1`, `error`: `Could not reach Nebula sync at <url>` | Check for a `NEBULA_` override in the environment (the CLI names them on stderr without `--json`), retry without it, then report it. |
| Network or service error | Exit `1` | Report it once; do not loop. |

With `--json`, each failure prints exactly one line on stderr,
`{"error":{"code":"...","message":"...","trace_id":"..."}}`; `trace_id` is
absent on a `usage` error. `code` and exit are `error` (`1`), `usage` (`2`),
`auth_required` (`3`), `waiting` (`4`, for example `tasks stop` on a Task
with an open question), `outcome_unknown` (`5`), `not_found` (`6`),
`timeout` (`7`), or `personal_device_agent_consent` (`1`: an agent that runs
on the user's computer joins a Channel only with their confirmation in the
app). A `waiting` or `failed` chat or `tasks wait` result is not an error
line: it prints its object on stdout. Without `--json`, errors are plain text
followed by a `Trace:` line.
