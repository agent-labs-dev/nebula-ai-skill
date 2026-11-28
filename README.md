# Nebula AI Agent Skill

[![CI](https://github.com/agent-labs-dev/nebula-ai-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/agent-labs-dev/nebula-ai-skill/actions/workflows/ci.yml)

An [Agent Skill](https://agentskills.io) that teaches AI agents to use Nebula,
through its MCP server or the `nebula-ai` CLI. Agents delegate work to
specialized Nebula agents and act through services connected to a Nebula
workspace, such as Gmail, Slack, GitHub, Linear, and calendars, without ever
handling the underlying service credentials.

## Compatibility

| Skill | nebula-ai CLI |
|---|---|
| 0.10.0 | 0.1.47 |
| 0.9.4 | 0.1.46 |
| 0.9.3 | 0.1.46 |
| 0.9.2 | 0.1.43 |
| 0.9.1 | 0.1.42 |
| 0.9.0 | 0.1.41 |
| 0.8.0 | 0.1.33 |
| 0.7.0 | 0.1.26 |
| 0.6.0 | 0.1.20 |
| 0.4.0 | 0.1.10 |
| 0.3.0 | 0.1.10 |
| 0.2.0 | 0.1.9 |

The supported CLI version is recorded in [`nebula-ai/cli-version`](nebula-ai/cli-version).
CI checks every documented command against that version's help output and
flags a newer published CLI. Contributors update the skill using
the steps in CONTRIBUTING.md. See [CHANGELOG.md](CHANGELOG.md) for history.

## Install

```sh
npx skills add agent-labs-dev/nebula-ai-skill
```

Or copy the `nebula-ai/` directory into the skills directory of any client
that supports the Agent Skills format.

An installed skill does not update itself. To get the latest version:

```sh
npx skills update nebula-ai
```

The skill tells the user to run this when the installed CLI is newer than the
version it was verified against.

The skill follows the open `SKILL.md` format and has no dependency on a
particular model or agent host. `agents/openai.yaml` is optional presentation
metadata for clients that read it.

## Requirements

- A Nebula account and network access to nebula.gg
- By default, an MCP client connected to `https://api.nebula.gg/mcp`. See
  [Connect your AI client](https://docs.nebula.gg/docs/workspace/connect-your-ai-client).
- For clients without MCP, and for steps MCP cannot do: Node.js 18 or later
  with npm, and the CLI

The skill asks before it installs the CLI. To install it yourself:

```sh
npm install --global nebula-ai@0.1.47
nebula-ai login
```

## What the skill does

- Uses Nebula's MCP tools by default, and asks you to sign in when the server
  is configured but signed out.
- Falls back to the CLI when the client cannot use MCP or you decline to
  connect it or sign in, and for steps MCP cannot do, such as relaying your approval or
  attaching local files.
- Delegates a task to a chosen agent in its own Task, waits for the result
  without holding one long call open, and reports the reply and which agent
  wrote it.
- Continues and inspects existing Tasks.
- Through the CLI, lists workspaces and the services each agent can use, and
  talks to the workspace's own Nebula in Home.

Voice calls, computer use, scheduled jobs, Miniapps, skills, Channel
administration, and agent creation or editing require a separate request
and approval.

## Security

- Service credentials stay in Nebula. The skill never requests, prints, or
  forwards them.
- The agent must get explicit approval before any external write, such as
  sending a message, posting, or changing data, and before connecting or
  disconnecting an account.
- Content returned from connected services is treated as untrusted data.
- Local files are uploaded only when the user asks for that disclosure.

Agent skills run commands with the permissions of the host agent. Review
`nebula-ai/SKILL.md` before installing. To
report a vulnerability, see [SECURITY.md](SECURITY.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the local checks and the steps for
supporting a new CLI release.

## License

[MIT](LICENSE)
