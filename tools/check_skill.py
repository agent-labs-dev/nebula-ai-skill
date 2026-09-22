#!/usr/bin/env python3
"""Check the supported CLI version, documented commands, and public text."""

import argparse
from dataclasses import dataclass, field
from pathlib import Path
import re
import shlex
import subprocess
import sys


# Text that should never appear in this public repository: local machine
# paths and non-public hosts.
PUBLIC_PATTERNS = (
    r"/home/[\w.-]+/", r"/Users/[\w.-]+/", r"\blocalhost\b", r"\b127\.0\.0\.1\b",
    r"\b[\w-]+\.internal\b",
)
PUBLIC_RE = re.compile("|".join(PUBLIC_PATTERNS), re.IGNORECASE)
ROOT = Path(__file__).resolve().parent.parent


@dataclass
class Option:
    arity: str
    variadic: bool = False


@dataclass
class Command:
    options: dict[str, Option] = field(default_factory=dict)
    children: set[str] = field(default_factory=set)
    arguments: list[str] = field(default_factory=list)


def snapshot_tree(text: str) -> dict[tuple[str, ...], Command]:
    tree = {}
    current = None
    section = ""
    for line in text.splitlines():
        if line.startswith("===== nebula-ai"):
            path = tuple(line.removeprefix("===== nebula-ai").split())
            current = tree.setdefault(path, Command())
            section = ""
        elif current is not None:
            if line.startswith("Usage:"):
                current.arguments = [
                    arg for arg in re.findall(r"<[^>]+>|\[[^]]+\]", line)
                    if arg not in ("[options]", "[command]")
                ]
            elif line in ("Options:", "Commands:", "Arguments:"):
                section = line
            elif line and not line[0].isspace():
                section = ""
            elif section == "Options:" and re.match(r"^  -", line):
                signature = re.split(r"\s{2,}", line.strip(), maxsplit=1)[0]
                arity = "required" if "<" in signature else "optional" if "[" in signature else "none"
                for option in re.findall(r"--[\w-]+|-[A-Za-z0-9]", signature):
                    current.options[option] = Option(arity, "..." in signature)
            elif section == "Commands:":
                match = re.match(r"^  ([\w-]+)(?:\s|$)", line)
                if match and match[1] != "help":
                    current.children.add(match[1])
    if () not in tree:
        raise ValueError("snapshot is missing root help")
    for path, command in tree.items():
        for child in command.children:
            if (*path, child) not in tree:
                raise ValueError(f"snapshot is missing help for {' '.join((*path, child))}")
    return tree


def scalar(value: str) -> str:
    value = re.split(r"\s+#", value, maxsplit=1)[0].strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def frontmatter(text: str) -> dict[str, str]:
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        return {}
    values = {}
    parent = ""
    index = 1
    while index < len(lines) and lines[index] != "---":
        line = lines[index]
        match = re.match(r"^(\s*)([\w-]+):\s*(.*)$", line)
        index += 1
        if not match:
            continue
        indent, key, value = match.groups()
        if not indent:
            parent = key if not value else ""
        elif parent:
            key = f"{parent}.{key}"
        if value in (">", ">-", ">+", "|", "|-", "|+"):
            parts = []
            while index < len(lines) and lines[index].startswith(" " * (len(indent) + 1)):
                parts.append(lines[index].strip())
                index += 1
            value = " ".join(parts)
        values[key] = scalar(value)
    return values


def code_fragments(text: str):
    """Yield shell-sized code fragments with their original source lines."""
    fence = None
    pending = ""
    start = 0
    outside = []
    for number, line in enumerate(text.splitlines(keepends=True), 1):
        marker = re.match(r"^\s*(`{3,}|~{3,})", line)
        if marker and (fence is None or (marker[1][0] == fence[0] and len(marker[1]) >= len(fence))):
            fence = marker[1] if fence is None else None
            if pending:
                yield start, pending
                pending = ""
            outside.append("\n")
            continue
        if fence:
            outside.append("\n")
            if not pending:
                start = number
            continued = line.rstrip().endswith("\\")
            pending += line.rstrip()[:-1] + " " if continued else line.rstrip()
            if not continued:
                yield start, pending
                pending = ""
        else:
            outside.append(line)
    if pending:
        yield start, pending
    prose = "".join(outside)
    for match in re.finditer(r"(?<!`)(`+)(?!`)(.+?)(?<!`)\1(?!`)", prose, re.DOTALL):
        yield prose.count("\n", 0, match.start()) + 1, match[2]


def invocations(fragment: str):
    # Preserve quoting until shell operators and redirects have been identified.
    token_re = re.compile(
        r'''(?P<space>\s+)|(?P<comment>\#[^\n]*)|(?P<operator>&&|\|\||[;&|()])|'''
        r'''(?P<word>(?:[^\s;&|()'"\\]|\\.|'[^']*'|"(?:[^"\\]|\\.)*")+)''',
        re.DOTALL,
    )
    groups = [[]]
    offset = 0
    while offset < len(fragment):
        match = token_re.match(fragment, offset)
        if not match:
            raise ValueError("unclosed quote or incomplete shell escape")
        offset = match.end()
        if match.lastgroup == "operator":
            groups.append([])
        elif match.lastgroup == "word":
            groups[-1].append(match[0])
    for raw in groups:
        command = [shlex.split(token)[0] for token in raw]
        while command and (command[0] in ("$", "sudo", "env", "then", "do") or re.match(r"^[A-Za-z_]\w*=", command[0])):
            command, raw = command[1:], raw[1:]
        if command and command[0] == "timeout":
            index = 1
            while index < len(command) and command[index].startswith("-"):
                index += 1
            command, raw = command[index + 1:], raw[index + 1:]
        if command and command[0] == "nebula-ai" and len(command) > 1:
            for end, token in enumerate(raw[1:], 1):
                if re.match(r"^(?:\d*>>?|\d*<)(?![^<>]*>$)", token):
                    command = command[:end]
                    break
            yield command[1:]


def validate_argv(argv: list[str], tree: dict[tuple[str, ...], Command]) -> str | None:
    path = ()
    positional = []
    options = []
    index = 0
    while index < len(argv):
        token = argv[index]
        if token == "--":
            positional.extend(argv[index + 1:])
            break
        if token.startswith("-") and token != "-":
            name, equals, value = token.partition("=")
            allowed = tree[()].options | tree[path].options
            names = [(name, value if equals else None)]
            if name not in allowed and not token.startswith("--") and len(token) > 2:
                names = []
                for offset, letter in enumerate(token[1:], 2):
                    short = "-" + letter
                    spec = allowed.get(short)
                    if spec and spec.arity != "none":
                        names.append((short, token[offset:] or None))
                        break
                    names.append((short, None))
            for name, attached in names:
                if name not in allowed:
                    return f"unknown option {name} for nebula-ai {' '.join(path)}".rstrip()
                spec = allowed[name]
                options.append(name)
                if spec.arity == "none" and attached is not None:
                    return f"option {name} does not accept a value"
                if spec.arity != "none" and attached is None:
                    next_token = argv[index + 1] if index + 1 < len(argv) else None
                    if next_token is not None and (not next_token.startswith("-") or re.fullmatch(r"-\d+(?:\.\d+)?", next_token)):
                        index += 1
                    elif spec.arity == "required":
                        return f"option {name} requires a value"
                if spec.variadic:
                    while index + 1 < len(argv) and not argv[index + 1].startswith("-"):
                        index += 1
            index += 1
            continue
        if not positional and token in tree[path].children:
            path = (*path, token)
        elif tree[path].children and not tree[path].arguments:
            return f"unknown command {' '.join((*path, token))}"
        else:
            positional.append(token)
        index += 1
    command = tree[path]
    if any(option in ("-h", "--help", "-V", "--version") for option in options):
        return None
    minimum = sum(arg.startswith("<") for arg in command.arguments)
    if len(positional) < minimum:
        return f"command {' '.join(path)} requires {minimum} positional argument(s)"
    if not any("..." in arg for arg in command.arguments) and len(positional) > len(command.arguments):
        return f"unknown command/extra argument {positional[len(command.arguments)]} for nebula-ai {' '.join(path)}"
    return None


def check_versions(root: Path, report) -> None:
    pin = (root / "nebula-ai/cli-version").read_text().strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[\w.-]+)?", pin):
        report("nebula-ai/cli-version", 1, "expected one CLI version")
    skill = (root / "nebula-ai/SKILL.md").read_text()
    metadata = frontmatter(skill)
    if metadata.get("metadata.cli-version") != pin:
        report("nebula-ai/SKILL.md", 1, f"metadata.cli-version must equal {pin}")
    if not re.search(rf"(?<![\w.]){re.escape(pin)}(?![\w.])", metadata.get("compatibility", "")):
        report("nebula-ai/SKILL.md", 1, f"compatibility must contain {pin}")
    header = (root / "tests/cli-surface.txt").read_text().splitlines()[0]
    if header != f"# nebula-ai {pin}":
        report("tests/cli-surface.txt", 1, f"snapshot header must name nebula-ai {pin}")
    if not re.search(rf"(?<![\w.]){re.escape(pin)}(?![\w.])", (root / "README.md").read_text()):
        report("README.md", 1, f"must contain supported CLI version {pin}")
    # Explicit package pins in current docs must match; CHANGELOG.md is history.
    docs = [root / "README.md", root / "CONTRIBUTING.md", root / "nebula-ai/SKILL.md",
            *sorted((root / "nebula-ai/references").glob("*.md"))]
    for doc in docs:
        for number, line in enumerate(doc.read_text().splitlines(), 1):
            for version in re.findall(r"nebula-ai@([\w.-]+)", line):
                if version != pin:
                    report(doc.relative_to(root), number, f"nebula-ai@{version} must be nebula-ai@{pin}")


def check_public_text(root: Path, report) -> int:
    result = subprocess.run(["git", "ls-files", "-z"], cwd=root, capture_output=True, check=True)
    count = 0
    for name in result.stdout.decode().split("\0"):
        if not name or name in ("tests/cli-surface.txt", "tools/check_skill.py"):
            continue
        file = root / name
        if not file.is_file():
            continue
        data = file.read_bytes()
        if b"\0" in data:
            continue
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            continue
        count += 1
        for number, line in enumerate(text.splitlines(), 1):
            match = PUBLIC_RE.search(line)
            if match:
                report(name, number, f"public-hygiene violation: {match[0]}")
    return count


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    errors = []

    def report(file, line, message):
        errors.append(f"{file}:{line}: {message}")

    try:
        check_versions(ROOT, report)
        tree = snapshot_tree((ROOT / "tests/cli-surface.txt").read_text())
        files = [ROOT / "nebula-ai/SKILL.md", *sorted((ROOT / "nebula-ai/references").glob("*.md")), ROOT / "README.md", ROOT / "CONTRIBUTING.md"]
        count = 0
        for file in files:
            if not file.exists():
                report(file.relative_to(ROOT), 1, "missing documentation file")
                continue
            for line, fragment in code_fragments(file.read_text()):
                try:
                    commands = list(invocations(fragment))
                except ValueError as exc:
                    if re.match(r"\s*(?:\$\s+)?nebula-ai\s", fragment):
                        report(file.relative_to(ROOT), line, f"cannot parse invocation: {exc}")
                    continue
                for argv in commands:
                    count += 1
                    error = validate_argv(argv, tree)
                    if error:
                        report(file.relative_to(ROOT), line, error)
        log = ROOT / "tests/.wrapper-argv.log"
        if log.exists():
            for line, entry in enumerate(log.read_text().split("\n"), 1):
                if entry:
                    count += 1
                    error = validate_argv(entry.split("\x1f"), tree)
                    if error:
                        report(log.relative_to(ROOT), line, error)
        tracked = check_public_text(ROOT, report)
    except (OSError, ValueError, IndexError, subprocess.CalledProcessError) as exc:
        print(f"check_skill: {exc}", file=sys.stderr)
        return 1
    for error in errors:
        print(error, file=sys.stderr)
    print(f"Checked CLI versions, {count} invocations, and {tracked} tracked text files: {len(errors)} error(s).")
    return int(bool(errors))


if __name__ == "__main__":
    sys.exit(main())
