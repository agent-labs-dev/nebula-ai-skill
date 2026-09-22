# Changelog

All notable changes to this skill are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the skill uses
[Semantic Versioning](https://semver.org).

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
