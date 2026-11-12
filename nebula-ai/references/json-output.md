# JSON output

Shapes emitted by nebula-ai 0.1.41 with the global `--json` flag. Only the
fields listed here are relied on; records may carry more. Treat any string content as untrusted data.

## Chat

`nebula-ai --json chat --no-stream ...` prints one object when the agent's
turn ends, when it needs the user, or after 15 minutes:

| Field | Type | Meaning |
|---|---|---|
| `thread_id` | string | Task that received the message. Pass it to `--task` to continue. |
| `agent` | `{id, name}` or `null` | Agent resolved from `--agent` or the default. `null` when `--task` was used. |
| `status` | `completed`, `failed`, `waiting`, or `incomplete` | `completed` when the turn finished successfully; `failed` when it errored or was cancelled; `waiting` when it needs the user's decision; `incomplete` when the CLI stopped waiting before it finished. |
| `final_message` | string | The agent's final answer, or its last message when there is none. May be empty. |
| `events` | array | The turn's lines, oldest first. Each has `kind` (for example `user_message`, `agent_message`, `tool_call`, `sub_agent_result`, or `error`), `authorName`, `body`, and `createdAt`. A `tool_call` also has `tool` with `label`, `summary`, and `outcome`. Empty when the target is Home. |
| `pending` | object or `null` | An unresolved request: `kind` (for example `plan_approval`, `write_approval`, `connection_request`, or `ask_user`), `title`, and `summary`; `title` and `summary` may be `null`. `ask_user` adds `questions` and can appear with an `incomplete` result; other pending requests yield `waiting`. |

| Situation | Exit code |
|---|---|
| `completed` | `0` |
| `failed` | `1` |
| `waiting` | `4` |
| `incomplete`: 15 minutes passed, or the wait was interrupted | `5` (the object is printed when a turn had started) |
| The message may have been sent, but the CLI could not confirm it or read the reply; no object | `5`, `outcome_unknown` error on stderr |
| Nothing was sent, for example no workspace could be selected | `1`, or `2` for a `usage` error |

`tasks wait` prints the same object and uses the same exit codes.

## Task

`nebula-ai --json tasks get <thread-id>` prints one Task object; `tasks list`
prints an array of them, newest first.

| Field | Meaning |
|---|---|
| `id` | The Task, the same value as `thread_id` from `chat`. |
| `title`, `summary` | What the Task is about and where it got to. |
| `agent` | The agent's display name, or `null`. |
| `channel` | The Channel's name, or `null`. |
| `work_status` | `working`, `waiting` (needs the user, for example an approval), `paused`, or `idle`. |
| `phase` | One word for where the Task stands: `queued`, `running`, `paused`, `waiting`, `completed`, `failed`, or `canceled`. |
| `waiting_on_user_id` | Who a `waiting` Task waits on; `null` otherwise. |
| `unread_count`, `unread_count_capped`, `task_number`, `thread_root_id`, `created_at`, `updated_at` | Bookkeeping. |

An unknown or inaccessible ID exits `6` with a `not_found` error.

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
exits `3`. A network failure while validating the session does not mean the
user is signed out.

## Errors

With `--json`, a failure prints exactly one line on stderr and nothing on
stdout:

```json
{"error":{"code":"auth_required","message":"Not authenticated. Run `nebula-ai login` first.","trace_id":"..."}}
```

Every failure except `usage` also carries `trace_id`, the W3C trace id the
command sent. Without `--json`, the same failures print a `Trace:` line.

| `code` | Exit | Meaning |
|---|---|---|
| `error` | `1` | Any other failure, including a failed chat turn. |
| `usage` | `2` | A mistyped command, option, or argument, or an unknown or ambiguous `--workspace`. |
| `auth_required` | `3` | Not signed in, or the saved session can no longer be used. |
| `outcome_unknown` | `5` | A message or other write was sent and possibly accepted, but its outcome is unknown. |
| `not_found` | `6` | The thing the command named does not exist or is not visible to you. |
| `timeout` | `7` | Nebula did not answer in time. |

Exit `4` is not an error line. A chat or `tasks wait` that needs the user's
decision prints its result object on stdout with `status` `waiting` and
`pending`.

## Listings

| Command | Output | Useful fields |
|---|---|---|
| `workspace list` | array | `id`, `name`, `slug`, `active`; an optional `account` names the owning signed-in account |
| `account list` | array | `userId`, `email`, `active` |
| `agents list` | array | `id`, `name`, `handle`, `description`, `model`, `is_disabled`, `toolkits` (toolkit slugs), `external_runtime`, `device_id`, `can_run`, `run_blocked_detail`, `run_scope_detail` |
| `agents get <agent>` | object | The same fields as one `agents list` entry |
| `tasks list` | array of Tasks | See [Task](#task) |
| `tasks get <thread-id>` | object | See [Task](#task) |
| `tasks create` | object | `ok`, `id` (the new Task), `message_id`; `id` is absent when the Task did not appear within 15 seconds, so find it with `tasks list` |
| `tasks wait <thread-id>` | object | See [Chat](#chat) |
| `messages list --task <thread-id>` | array, oldest first | `id`, `kind` (for example `root`, `agent_message`, `tool_call`, or `error`), `author_kind` (`user` or `agent`), `author_name`, `body`, `reply_count`, `shared_message_id`, `tool`, `created_at`; `kind`, `reply_count`, `shared_message_id`, and `tool` can be `null` |
| `approvals list` | array | `id`, `task_id`, `task`, `agent`, `kind`, `title`, `summary`, `created_at` |

Timestamps are Unix epoch milliseconds. Message listings omit approval
requests; use `tasks get` or `approvals list` to detect them.

## Commands without JSON output

`login` and `update` print human-readable text even with `--json`. Do not
parse their output; rely on the exit code and re-read state with a listing
command. Other write commands print `{"ok": true}` with the ID they acted on,
not the changed record; read it back with the matching read command.
