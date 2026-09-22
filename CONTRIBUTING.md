# Contributing

Thanks for helping improve the Nebula AI skill. Issues and pull requests are
welcome.

## Layout

| Path | Purpose |
|---|---|
| `nebula-ai/SKILL.md` | Instructions loaded by the agent. Keep it concise; put detail in `references/`. |
| `nebula-ai/references/` | Command and output reference, loaded on demand. |
| `nebula-ai/cli-version` | The one CLI version the skill is verified against. |
| `tests/cli-surface.txt` | Snapshot of that version's full `--help` tree. Generated; do not edit. |
| `tools/` | Snapshot and consistency checks used by CI. |
| `evals/evals.json` | Scenarios for manually evaluating agent behavior. |

## Local checks

Requires a POSIX shell, Python 3.11+, Node.js 18+, and optionally
[ShellCheck](https://www.shellcheck.net) and [uv](https://docs.astral.sh/uv/).

```sh
python3 tools/check_skill.py
tools/snapshot-cli.sh --check
shellcheck tools/*.sh
```

`check_skill.py` verifies that every `nebula-ai` command in the docs exists,
with valid options, in the snapshot. It also
checks that version numbers agree across the repository.

## Updating the supported CLI version

CI fails when npm publishes a newer `nebula-ai` than the one in
`nebula-ai/cli-version`, and a scheduled workflow opens an issue. To update:

1. Write the new version to `nebula-ai/cli-version`.
2. Run `tools/snapshot-cli.sh` to regenerate `tests/cli-surface.txt`, and read
   the diff to see what changed.
3. Update `SKILL.md` frontmatter (`compatibility` and `metadata.cli-version`),
   the references, and the README compatibility table.
4. Check output shapes in `references/json-output.md` against the new release.
5. Bump `metadata.version` and add a `CHANGELOG.md` entry.
6. Run the local checks and open a pull request.

## Style

- Write instructions as direct, imperative steps an agent can follow.
- Describe only released, publicly documented CLI behavior.
- Use placeholders such as `<agent-slug>` and `<thread-id>`, never real IDs,
  accounts, or email addresses.
- Call the CLI directly. If a task needs a helper script, fix the CLI instead.

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org).
