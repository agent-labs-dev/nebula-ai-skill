# Nebula CLI reference

Use this reference when the main workflow does not provide enough command
detail. Run `<command> --help` before relying on options not listed here.

## Installation and authentication

```sh
npm install --global nebula-ai
nebula-ai --version
nebula-ai login
nebula-ai status
nebula-ai logout
```

`login` uses device-flow pairing. Keep authentication material in the CLI's
credential store; never collect it in chat or save it in a project.

## Global options

```text
--workspace <id-or-slug>  Select a workspace for this command
--json                    Request raw JSON where supported
--no-color                Disable terminal colors
--log-level <level>       error, warn, info, debug, or trace
```

Current agent-ready CLI builds emit one top-level value for every `--json`
invocation. Older CLI 0.1.3 builds ignore `--json` for `status` and emit chat
events as JSONL; run `nebula-ai update` if either legacy shape appears. Do not
parse human output as a durable API contract.

## Discovery

```sh
nebula-ai --json agents list
nebula-ai --json integrations list
nebula-ai --json channels list
nebula-ai agents get <agent-id>
nebula-ai channels get <channel-id>
nebula-ai channels messages --limit 50 <channel-id>
```

Agent records may include long descriptions and skill lists. Select only the
fields needed to choose an agent; avoid copying complete records into context.

## Chat

```sh
nebula-ai --json chat --no-stream --agent "<name-or-slug>" "<message>"
nebula-ai --json chat --no-stream --channel "<thread-id>" "<follow-up>"
```

Without `--agent` or `--channel`, chat uses the first active agent. Prefer
`--no-stream` in automated runs. JSON output is one object with `thread_id`,
`agent`, `status`, `final_message`, and `events`. Preserve `thread_id` from the
original response and pass that exact value to `--channel` for continuations.
Despite the option name, `--channel` targets a thread ID; do not replace it with
the containing channel's ID.

## Integrations

```sh
nebula-ai integrations list
nebula-ai integrations connect <provider>
nebula-ai integrations disconnect <provider> [account-id]
```

CLI 0.1.3 advertises direct connection flows for Slack, Discord, GitHub, and
Linear. Other services, including Gmail, may already be attached to individual
Nebula agents even though the CLI does not yet advertise a direct connection
command. If the needed account is absent, send the user to Nebula's supported
connection flow rather than collecting credentials.

Connecting or disconnecting an integration changes external authorization and
requires explicit user approval.

## Failures

- Exit `127`: dependency missing. Explain the install command.
- Authentication missing: run `nebula-ai login` and wait for user pairing.
- Agent missing or unconfigured: rediscover agents; do not silently substitute.
- Integration missing: identify the service and ask the user to connect it.
- Approval required: stop and present the exact proposed action.
- Network or service failure: report it once; do not loop indefinitely.
