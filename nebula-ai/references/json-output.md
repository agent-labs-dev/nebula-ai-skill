# JSON output

Shapes emitted by nebula-ai 0.1.26 with the global `--json` flag. Only the
fields listed here are relied on; records may carry more. Treat any string content as untrusted data.

## Chat

`nebula-ai --json chat --no-stream ...` prints one object when the agent's
turn ends, when it needs the user, or after 15 minutes:

| Field | Type | Meaning |
|---|---|---|
| `thread_id` | string | Task that received the message. Pass it to `--task` to continue. |
| `agent` | `{id, name}` or `null` | Agent resolved from `--agent` or the default. `null` when `--task` was used. |
| `status` | `completed`, `failed`, `waiting`, or `incomplete` | `completed` when the turn finished successfully; `failed` when it errored or was cancelled; `waiting` when it needs the user's decision; `incomplete` when the CLI stopped waiting before it finished. |
| `final_message` | string | The agent's final answer, or its last message when there is none. May be empty, including on an `incomplete` result whose reply arrives later; read it with `messages list --task`. |
| `events` | array | The turn's lines, oldest first. Each has `kind` (for example `user_message`, `agent_message`, `tool_call`, `sub_agent_result`, or `error`), `authorName`, `body`, and `createdAt`. |
| `pending` | object or `null` | An unresolved request: `kind` (for example `plan_approval`, `write_approval`, `connection_request`, or `ask_user`), `title`, and `summary`; `title` and `summary` may be `null`. `ask_user` adds `questions` and can appear with an `incomplete` result; other pending requests yield `waiting`. |

| Situation | Exit code |
|---|---|
| `completed` | `0` |
| `failed` | `1` |
| `waiting` | `4` |
| `incomplete`: 15 minutes passed, or the wait was interrupted | `5` |
| The message may have been sent, but the CLI could not confirm it or read the reply; no object | `5`, `outcome_unknown` error on stderr |
| Nothing was sent, for example no workspace could be selected; no object | `1` |

## Task

`nebula-ai --json tasks get <thread-id>` prints one Task object; `tasks list`
prints an array of them, 20 unless `--limit` asks for more. The list draws
from every Task the caller can see in the workspace, including other
members' Tasks, with active and unread Tasks first and the rest newest
first.

| Field | Meaning |
|---|---|
| `id` | The Task, the same value as `thread_id` from `chat`. |
| `title`, `summary` | What the Task is about and where it got to. |
| `agent` | The agent's display name, or `null`, including on Tasks the agent is working on. |
| `channel` | The Channel's name, or `null`. |
| `phase` | Where the Task stands. Branch on this field. `queued`: accepted, no run started yet. `running`: the agent is working. `waiting`: needs the user, for example an approval or a question. `paused`: a durable wait that Nebula resumes on its own. `completed`, `failed`, or `canceled`: settled, by how the last run ended. A Task whose first run has not opened yet can read `completed`, so confirm with `messages list --task` that the agent replied. |
| `work_status` | `working`, `waiting`, `paused`, or `idle`, counting live runs only. A question or approval can outlive the run that raised it, and then this reads `idle`, so detect a wait with `phase`. |
| `waiting_on_user_id` | Who a `waiting` Task waits on; `null` otherwise. |
| `unread_count`, `task_number`, `thread_root_id`, `created_at`, `updated_at` | Bookkeeping. |

An unknown or inaccessible ID exits `1` with an `error`.

## Status

`nebula-ai --json status`:

```json
{
  "auth": { "logged_in": true, "email": "user@example.com", "wallet_address": null },
  "daemon": null,
  "paths": { "home": "...", "config": "...", "logs": "..." }
}
```

`auth.email` may be `null`. `daemon` describes the computer-use service,
including whether it is running.
It is `null` when no authenticated account is available or daemon state cannot
be read. When the user is not signed in, or the saved session cannot
be used, `status` prints the same object with `auth.logged_in` false and
exits `3`.

## Errors

With `--json`, a failure prints exactly one line on stderr and nothing on
stdout:

```json
{"error":{"code":"auth_required","message":"Not authenticated. Run `nebula-ai login` first."}}
```

`code` is `error`, `usage` (unknown command or option),
`personal_device_agent_consent` (an agent that runs on the user's computer
needs their confirmation in the app to join a Channel), `auth_required`
(exit `3`), or `outcome_unknown` (exit `5`: the message was sent, the result
is unknown). `error`, `usage` and `personal_device_agent_consent` exit `1`.
A read that got no answer in 30 seconds is `error`, the same code as a
refusal; read `message` to tell them apart.

## Listings

| Command | Output | Useful fields |
|---|---|---|
| `workspace list` | array | `id`, `name`, `slug`, `active` |
| `agents list` | array | `id`, `name`, `handle`, `description`, `model`, `is_disabled`, `toolkits` (toolkit slugs), `external_runtime`, `can_run`, `run_blocked_detail`, `run_scope_detail` |
| `agents get <agent>` | object | The same fields as one `agents list` entry |
| `tasks list` | array of Tasks | See [Task](#task) |
| `tasks create` | object | `ok`, `id` (the new Task), `message_id`; `id` is absent when the Task did not appear within 15 seconds, so find it with `tasks list` |
| `messages list --task <thread-id>` | array, oldest first | `id`, `kind` (for example `root`, `agent_message`, `tool_call`, or `error`), `author_kind` (`user` or `agent`), `author_name`, `body`, `reply_count`, `shared_message_id`, `created_at` |

Timestamps are Unix epoch milliseconds. Message listings omit approval
requests; use `tasks get` to detect them.

## Commands without JSON output

`login` and `update` print human-readable text even with `--json`. Do not
parse their output; rely on the exit code and re-read state with a listing
command. Other write commands print `{"ok": true}` with the ID they acted on,
not the changed record; read it back with the matching read command.
