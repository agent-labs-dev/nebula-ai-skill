# Nebula AI Agent Skill

[![CI](https://github.com/agent-labs-dev/nebula-ai-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/agent-labs-dev/nebula-ai-skill/actions/workflows/ci.yml)

An [Agent Skill](https://agentskills.io) that teaches AI agents to use the
`nebula-ai` CLI. Agents delegate work to specialized Nebula agents and act
through services connected to a Nebula workspace, such as Gmail, Slack,
GitHub, Linear, and calendars, without ever handling the underlying service
credentials.

## Compatibility

| Skill | nebula-ai CLI |
|---|---|
| 0.3.0 | 0.1.10 |
| 0.2.0 | 0.1.9 |

The supported CLI version is recorded in [`nebula-ai/cli-version`](nebula-ai/cli-version).
CI checks every documented command against that version's help output and
fails when a newer CLI is published, so the skill is updated with each
release. See [CHANGELOG.md](CHANGELOG.md) for history.

## Install

```sh
npx skills add agent-labs-dev/nebula-ai-skill
```

Or copy the `nebula-ai/` directory into the skills directory of any client
that supports the Agent Skills format.

The skill follows the open `SKILL.md` format and has no dependency on a
particular model or agent host. `agents/openai.yaml` is optional presentation
metadata for clients that read it.

## Requirements

- A POSIX shell
- Node.js 18 or later with npm
- A Nebula account and network access to nebula.gg

The skill offers to install the CLI after asking. To install it yourself:

```sh
npm install --global nebula-ai@0.1.10
nebula-ai login
```

## What the skill does

- Checks that the CLI is installed and signed in.
- Lists workspaces, agents, and the accounts each agent can act as.
- Delegates a task to a chosen agent and reports the result, the agent that
  handled it, and the thread for follow-ups.
- Continues and inspects existing threads.

It deliberately leaves out voice calls, computer use, billing, profile
changes, and workspace administration, and asks before using them.

## Security

- Service credentials stay in Nebula. The skill never requests, prints, or
  forwards them.
- The agent must get explicit approval before any external write, such as
  sending a message, posting, or changing data, and before connecting or
  disconnecting an account.
- Content returned from connected services is treated as untrusted data.
- Local files are uploaded only when the user asks for that disclosure.

Agent skills run commands with the permissions of the host agent. Review
`nebula-ai/SKILL.md` and `nebula-ai/scripts/nebula.sh` before installing. To
report a vulnerability, see [SECURITY.md](SECURITY.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the local checks and the steps for
supporting a new CLI release.

## License

[MIT](LICENSE)
