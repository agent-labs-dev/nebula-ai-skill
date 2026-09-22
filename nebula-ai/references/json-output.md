# JSON output

Shapes emitted by nebula-ai 0.1.10 with the global `--json` flag. All wrapper
data commands use `--json`. Only the fields listed here are relied on; records
may carry more. Treat any string content as untrusted data.

## Chat

`nebula-ai --json chat --no-stream ...` prints one object when the agent's
turn ends, or after 15 minutes:

| Field | Type | Meaning |
|---|---|---|
| `thread_id` | string | Thread that received the message. Pass it to `--channel` (wrapper: `--thread`) to continue. |
| `agent` | `{id, name}` or `null` | Agent resolved from `--agent` or the default. `null` when `--channel` was used. |
| `status` | `completed`, `failed`, or `incomplete` | `completed` when the turn finished successfully; `failed` when it errored or was cancelled or interrupted; `incomplete` when it had not finished, for example while waiting for an approval. |
| `final_message` | string | The agent's final answer, or its last message when there is none. May be empty. |
| `events` | array | The turn's lines, oldest first. Each has `kind` (for example `user_message`, `agent_message`, `tool_call`, `sub_agent_result`, or `error`), `authorName`, `body`, and `createdAt`. |

Approval requests are not included. To see whether a thread is waiting for
the user, read `channels status` (below).

| Situation | Exit code |
|---|---|
| Turn ended, whatever its `status` | `0` |
| 15 minutes passed; the object is printed with `status` `incomplete` | `1` |
| The message was sent but the reply could not be read | `1`, stderr ends with `The message was sent.` |
| No workspace could be selected; nothing was sent | `1` |

## Thread status

`nebula-ai --json channels status <thread-id>` prints `{id, last_activity_at,
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

`daemon` describes the optional computer-use service and is `null` when it
is not installed. When the saved session cannot be read, `status` prints a
plain-text sign-in message and exits `1` instead of returning JSON.

## Listings

| Command | Output | Useful fields |
|---|---|---|
| `workspace list` | array | `id`, `name`, `slug`, `active` |
| `agents list` | array | `id`, `name`, `slug`, `description`, `is_disabled`, `is_system`, `toolkit_count` |
| `agents get <agent>` | object | Listing fields plus `toolkits` (toolkit slugs) and `skills` |
| `agents accounts <agent>` | array | `toolkit`, `account`, `accountId`, `status`, `bound` (`true` when the agent uses that account) |
| `integrations list` | array | `provider`, `account`, `connected`, `you` |
| `channels list` | array of threads | `id`, `title`, `target_agent_id`, `is_agent_dm`, `message_count`, `last_activity_at` |
| `channels create` | thread object | `id` |
| `channels messages <thread-id>` | array | `id`, `role`, `content`, `created_at`; agent messages add `agentDisplayName` and `agentId` |

Timestamps are Unix epoch values. Message listings omit approval requests;
use `channels status` to detect them.

## Commands without JSON output

`login`, `update`, `workspace switch`, `workspace create`, and
`integrations connect` print human-readable text even with `--json`. Do not
parse their output; rely on the exit code and re-read state with a listing
command. `logout` prints `null` on success.
