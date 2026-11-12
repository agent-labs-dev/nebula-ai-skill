# Changelog

All notable changes to this skill are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the skill uses
[Semantic Versioning](https://semver.org).

## [0.8.0] - 2026-11-12

Verified against nebula-ai CLI 0.1.41.

### Changed

- Exit codes now include `usage` (`2`), `not_found` (`6`), and `timeout`
  (`7`). JSON failures other than `usage` carry a `trace_id`.
- `--workspace` accepts a name as well as an ID or slug, and an unknown or
  ambiguous value stops the command with a `usage` error instead of warning
  and falling back.
- `chat` can address the workspace's own `Nebula` agent in Home. `chat --new`
  starts a fresh chat with an agent, and a Home chat returns no `events`.
- `tasks wait` waits for a Task's newest turn and prints the same result and
  exit codes as `chat`. `tasks create --agent` is required, and `tasks list
  --mine` limits the list to Tasks you own or participate in.
- `agents list` gained `--limit`, `--query`, and `--runnable`; agents expose
  `device_id`.
- Support multiple signed-in accounts with `account list`, `account switch`,
  and `logout --all`; `workspace list` names each workspace's account.
- Document `approvals list`, and never approve or deny an ask for the user.
- Messages can be sent to a person with `messages send --to`.
- Document Task `unread_count_capped`, message `tool`, and a workspace's
  owning `account` in the JSON reference.
- List the ACP editor server (`acp`) as out of scope.

### Removed

- The instruction not to choose the workspace's own Nebula agent for `chat`:
  a chat with it now runs in Home rather than failing after sending.
- The claim that an unknown `--workspace` only warns and falls back.

## [0.7.0] - 2026-11-04

Verified against nebula-ai CLI 0.1.26.

### Changed

- Choose agents by `handle`; `agents list` no longer prints `slug`.
- Check a Task's work status with `tasks get`, which replaces `tasks status`.
- Read a Task's messages with `messages list --task`, which replaces
  `tasks messages`.
- `tasks create` takes the task text and starts the work, instead of creating
  an empty titled thread.
- Check that an agent's `toolkits` cover the service a task needs. The CLI no
  longer lists connected accounts.
- Document the 0.1.26 JSON shapes for agents, Tasks, messages and writes.
- Do not choose the workspace's own `Nebula` agent for `chat`: it runs no Task,
  so the chat fails after the message is sent.

### Removed

- Instructions for `agents accounts`, `integrations` and `usage`, which the
  CLI no longer has.

## [0.6.0] - 2026-10-09

Verified against nebula-ai CLI 0.1.20.

### Changed

- Use `tasks` and `chat --task` for agent conversations and follow-ups.
- Check the requesting user's connected accounts and their status, rather than
  agent account bindings. Remove instructions for `agents set-account`.
- Include command groups with aliases in the CLI help snapshot and validation.

## [0.5.0] - 2026-09-22

Verified against nebula-ai CLI 0.1.11.

### Changed

- `chat` exit codes now carry the outcome: `0` completed, `1` failed, `4`
  waiting for the user, `5` sent but the outcome is unknown (the 15-minute
  wait, an interruption, or an unreadable reply).
- A turn that needs the user's decision is reported by `chat` itself, with
  `status` `waiting` and the request in the new `pending` field.
- `status` exits `3` when signed out, and still prints its JSON object.
- `--json` failures are documented as one JSON line on stderr with an error
  `code`.

## [0.4.0] - 2026-09-22

Verified against nebula-ai CLI 0.1.10.

### Removed

- The `scripts/nebula.sh` wrapper and its tests. The skill now runs
  `nebula-ai --json` commands directly, and CI validates each documented
  command against the CLI's help snapshot.

### Changed

- Sign-in is checked with `nebula-ai --json status` and the installed version
  with `nebula-ai --version`.

## [0.3.0] - 2026-09-22

Verified against nebula-ai CLI 0.1.10.

### Changed

- Approval requests no longer appear in `chat` output. An `incomplete` result
  is now followed by `channels status`, where a `work_status` of `waiting`
  means Nebula needs the user's decision.
- `chat` `events` are documented as turn lines with a `kind`, replacing the
  typed run events of 0.1.9.
- `chat` waits up to 15 minutes, then exits `1` with an `incomplete` result;
  documented alongside the new exit `1` when the reply cannot be read after
  sending.
- `--workspace` applies to a single command; the 0.1.9 caveat about it being
  saved is removed.
- `channels messages` agent entries include `agentId`.

## [0.2.0] - 2026-09-22

Verified against nebula-ai CLI 0.1.9.

### Added

- `compatibility` and `metadata.cli-version` frontmatter recording the
  supported CLI version, with `nebula-ai/cli-version` as the single source.
- Wrapper commands: `workspaces`, `accounts`, `messages`, `version`, and
  `chat --thread` and `--context`.
- Result handling for `completed`, `failed`, and `incomplete` runs, including
  approval requests.
- Agent account checks with `agents accounts`, and separate threads with
  `channels create`.
- `references/json-output.md` documenting output shapes.
- CI: CLI help snapshot, validation of every documented command and option,
  wrapper tests, ShellCheck, and a check that fails when a newer CLI is
  published. A scheduled workflow opens an issue when that happens.
- Contributing guide, security policy, and evaluation scenarios.

### Changed

- `doctor` exits `3` when the CLI is not signed in instead of reporting
  success.
- `install` installs the verified CLI version.
- The wrapper rejects unknown options and passes messages after `--`, so text
  beginning with `-` is sent intact.
- Workspace selection is confirmed before use, since `--workspace` changes the
  saved default and an unknown value falls back silently.

### Fixed

- The claim that every command supports `--json`; the exceptions are listed.
- Outdated guidance on which integrations the CLI can connect.

## [0.1.0] - 2026-07-22

- Initial release.
