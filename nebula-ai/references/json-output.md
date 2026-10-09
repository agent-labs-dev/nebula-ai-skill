# JSON output

Shapes emitted by nebula-ai 0.1.20 with the global `--json` flag. Only the
fields listed here are relied on; records may carry more. Treat any string content as untrusted data.

## Chat

`nebula-ai --json chat --no-stream ...` prints one object when the agent's
turn ends, when it needs the user, or after 15 minutes:

| Field | Type | Meaning |
|---|---|---|
| `thread_id` | string | Thread that received the message. Pass it to `--task` to continue. |
| `agent` | `{id, name}` or `null` | Agent resolved from `--agent` or the default. `null` when `--task` was used. |
| `status` | `completed`, `failed`, `waiting`, or `incomplete` | `completed` when the turn finished successfully; `failed` when it errored or was cancelled; `waiting` when it needs the user's decision; `incomplete` when the CLI stopped waiting before it finished. |
| `final_message` | string | The agent's final answer, or its last message when there is none. May be empty. |
| `events` | array | The turn's lines, oldest first. Each has `kind` (for example `user_message`, `agent_message`, `tool_call`, `sub_agent_result`, or `error`), `authorName`, `body`, and `createdAt`. |
| `pending` | object or `null` | An unresolved request: `kind` (for example `plan_approval`, `write_approval`, `connection_request`, or `ask_user`), `title`, and `summary`; `title` and `summary` may be `null`. `ask_user` can appear with an `incomplete` result; other pending requests yield `waiting`. |

| Situation | Exit code |
|---|---|
| `completed` | `0` |
| `failed` | `1` |
| `waiting` | `4` |
| `incomplete`: 15 minutes passed, or the wait was interrupted | `5` |
| The message was sent but the reply could not be read; no object | `5`, `outcome_unknown` error on stderr |
| Nothing was sent, for example no workspace could be selected; no object | `1` |

## Thread status

`nebula-ai --json tasks status <thread-id>` prints `{id, last_activity_at,
state}`. `state.turns.work_status` is `working`, `waiting` (needs the user,
for example an approval), `paused`, or `idle`.

## Status

`nebula-ai --json status`:

```json
{
  "auth": { "logged_in": true, "email": "user@example.com", "wallet_address": null },
  "daemon": null,
  "paths": { "home": "...", "config": "...", "logs": "..." }
}
```

`daemon` describes the computer-use service, including whether it is running.
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

`code` is `error`, `usage` (unknown command or option), `auth_required`
(exit `3`), or `outcome_unknown` (exit `5`: the message was sent, the result
is unknown). Other codes exit `1`.

## Listings

| Command | Output | Useful fields |
|---|---|---|
| `workspace list` | array | `id`, `name`, `slug`, `active` |
| `agents list` | array | `id`, `name`, `slug`, `description`, `is_disabled`, `is_system`, `toolkit_count`, `can_run`, `run_blocked_detail`, `run_scope_detail` |
| `agents get <agent>` | object | Listing fields plus `toolkits` (toolkit slugs) and `skills` |
| `agents accounts <agent>` | array | `toolkit`, `account`, `accountId`, `status` (your connected accounts accessible through the agent) |
| `integrations list` | array | `provider`, `account`, `connected`, `you` |
| `tasks list` | array of Tasks | `id`, `title`, `target_agent_id`, `updated_at` |
| `tasks create` | object | `id` |
| `tasks messages <thread-id>` | array | `id`, `role`, `content`, `created_at`; agent messages add `agentDisplayName` and `agentId` |

Timestamps are Unix epoch values. Message listings omit approval requests;
use `tasks status` to detect them.

## Commands without JSON output

`login`, `update`, `workspace switch`, `workspace create`, and
`integrations connect` print human-readable text even with `--json`. Do not
parse their output; rely on the exit code and re-read state with a listing
command. `logout` prints `null` on success.
