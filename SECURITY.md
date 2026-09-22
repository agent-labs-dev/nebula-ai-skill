# Security policy

## Reporting a vulnerability

Please report security issues privately through
[GitHub private vulnerability reporting](https://github.com/agent-labs-dev/nebula-ai-skill/security/advisories/new).
Do not open a public issue.

Include the affected file or instruction, the agent host you used, and steps
to reproduce.

## Scope

This repository contains agent instructions. Relevant reports include:

- Instructions that could lead an agent to expose credentials, upload files,
  or perform external writes without the user's approval.
- Prompt-injection paths through content returned by connected services.
- Instructions that build CLI commands unsafely from untrusted content.

Vulnerabilities in the Nebula service or the `nebula-ai` CLI itself should
also be reported through the link above; we will route them.

## Supported versions

Only the latest release on the default branch is supported.
