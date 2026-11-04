# nebula-ai CLI reference

Commands relevant to delegation in nebula-ai 0.1.26. For anything else, read
the command's `--help` output before running it.

## Install and sign in

```sh
npm install --global nebula-ai@0.1.26
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
| `--workspace <id-or-slug>` | Use this workspace for this command only. An unknown value warns and falls back to the last-used workspace. |
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
nebula-ai --json agents list | jq '.[] | {handle, name, description, toolkits, can_run, run_blocked_detail, is_disabled}'
nebula-ai --json agents get <agent>
nebula-ai --json agents skills list <agent-id>
```

`agents list` prints every agent, which runs to hundreds of kilobytes on a
large workspace; project the fields you need with `jq`.

How each command finds an agent:

| Command | Accepts | Searches |
|---|---|---|
| `agents get` | ID or handle | Every agent |
| `tasks create -a` | Handle only; an ID or name is refused | The Channel's roster |
| `chat --agent` | ID, handle, or case-insensitive name | Only the 50 most recently updated agents, so a valid agent can be `Agent not found` on a large workspace |

Without `--agent`, chat uses the first enabled, non-system agent.

`toolkits` in the listing names the services an agent can use. Agents act
through the connected accounts of the person requesting work, and the CLI
cannot list or connect those accounts. If one is missing, ask the user to
connect it in Nebula.

## Chat

```sh
nebula-ai --json --no-color chat --no-stream --task "<thread-id>" -- "<follow-up>"
nebula-ai --json --no-color chat --no-stream --agent "<agent>" --context "docs/*.md" -- "<task>"
```

| Option | Effect |
|---|---|
| `-a, --agent <agent>` | Send to this agent's direct-message thread: an ID, handle, or name. Every request sent this way shares one thread and keeps its first title, so start unrelated work with `tasks create`. |
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
nebula-ai --json tasks list --channel <channel>
nebula-ai --json tasks get <thread-id>
nebula-ai --json messages list --task <thread-id> --limit 50
nebula-ai --json tasks create -a <agent-handle> -- "<task>"
```

`tasks list` returns 20 Tasks unless `--limit` asks for more. It draws from
every Task you can see in the workspace, including other members' Tasks:
active and unread Tasks come first, then the rest, newest first. `tasks get` shows a Task's title, Channel, agent, and `phase`.
`messages list --task` prints the most recent messages, oldest first.

`tasks create` is the way to start new work. It sends `<task>` to the agent
like `chat` does, so the same approval rules apply, but it returns once the
message is sent instead of waiting for the reply; poll `tasks get` on
`phase` and read the reply with `messages list --task`. `-a` is required and
takes a handle only. The Task starts in Home unless `--channel <channel>`
names another Channel, and the agent must be on that Channel's roster. It
cannot attach files. Continue it with `chat --task`.

## Exit codes and failures

| Situation | Behavior | Response |
|---|---|---|
| CLI missing | The shell reports `command not found` (exit `127`) | Ask, then install the verified version. |
| Not signed in | Exit `3`; `status` prints `auth.logged_in` false, other commands print an `auth_required` error | Run `nebula-ai login` and wait for the user. |
| Unknown command or option | Exit `1`, `usage` error | Check `--help`; the installed CLI may differ from 0.1.26. |
| Agent or Task not found | Exit `1`, nothing sent | Re-list agents or Tasks; do not substitute another. |
| Run failed | Exit `1`, JSON printed with `status` `failed` | Report it once. |
| Run waiting for the user | Exit `4`, JSON printed with `status` `waiting` and `pending` | See the result handling in SKILL.md. |
| Chat waited 15 minutes or was interrupted | Exit `5`, JSON printed with `status` `incomplete` | Poll `tasks get` on `phase`; do not resend. |
| Chat reply unreadable, or a write got no answer in 30 seconds | Exit `5`, `outcome_unknown` error | Read the thread with `messages list --task`; do not resend. |
| A read got no answer in 30 seconds | Exit `1`, `error` | Try once more. If it repeats, check for an exported `ZERO_CACHE_URL`, which points the CLI at another sync service, and retry with `env -u ZERO_CACHE_URL`. Then report it. |
| Network or service error | Exit `1` | Report it once; do not loop. |

With `--json`, each failure prints exactly one line on stderr,
`{"error":{"code":"...","message":"..."}}`. `code` is `error`, `usage`,
`auth_required`, `outcome_unknown`, or `personal_device_agent_consent`
(exit `1`: an agent that runs on the user's computer joins a Channel only
with their confirmation in the app). The CLI's own exit codes are `0`, `1`,
`3`, `4`, and `5`. Without `--json`, errors are plain text.
