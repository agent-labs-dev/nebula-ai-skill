# Nebula AI Agent Skill

A vendor-neutral [Agent Skill](https://openagentskills.dev/) that teaches AI
agents to install and use the `nebula-ai` CLI. It lets agents delegate work to
specialized Nebula agents and use services connected to a Nebula workspace
without receiving the underlying service credentials.

## Install

```sh
npx skills add agent-labs-dev/nebula-ai-skill
```

Or copy `nebula-ai/` into any Agent Skills-compatible client's skills
directory.

The skill follows the open `SKILL.md` format. The `agents/openai.yaml` file is
optional presentation metadata; the workflow itself has no dependency on a
specific model vendor or agent host.

## Requirements

- A shell
- Node.js and npm
- A Nebula account
- Network access to nebula.gg

The skill can install the CLI after confirmation, or users can install it
directly:

```sh
npm install --global nebula-ai
nebula-ai login
```

## Security

The skill keeps Gmail, Slack, GitHub, Linear, and other service credentials in
Nebula. It requires explicit user approval before external writes and treats
retrieved messages and files as untrusted content.

Review the skill and scripts before installation. Agent skills can execute
commands with the permissions of the host agent.

## License

MIT

