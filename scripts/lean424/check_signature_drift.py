#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


DECL_START = re.compile(r"^\s*(theorem|lemma|def|abbrev|opaque)\s+([^\s:(\[{]+)")
COMMENT = re.compile(r"--.*$")


def run(cmd: list[str]) -> str:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"command failed: {' '.join(cmd)}\n{proc.stderr}")
    return proc.stdout


def git_show(rev: str, path: str) -> str:
    proc = subprocess.run(
        ["git", "show", f"{rev}:{path}"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return ""
    return proc.stdout


def strip_comment(line: str) -> str:
    return COMMENT.sub("", line).rstrip()


def normalize_space(text: str) -> str:
    return " ".join(text.split())


def extract_decls(src: str) -> dict[str, str]:
    decls: dict[str, str] = {}
    lines = src.splitlines()
    i = 0
    while i < len(lines):
        line = strip_comment(lines[i])
        m = DECL_START.match(line)
        if m is None:
            i += 1
            continue

        name = m.group(2)
        chunk = [line]
        j = i + 1
        while ":=" not in line and j < len(lines):
            line = strip_comment(lines[j])
            chunk.append(line)
            if ":=" in line:
                break
            j += 1

        header = normalize_space("\n".join(chunk))
        header = header.split(":=", 1)[0].strip()
        decls[name] = header
        i = max(i + 1, j + 1)
    return decls


def load_allowlist(path: str | None) -> set[str]:
    if path is None:
        return set()
    out: set[str] = set()
    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        out.add(line)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="Check declaration signature drift on changed Lean files.")
    parser.add_argument("--base", default="origin/master")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--allowlist", default=None, help="Optional file of allowlisted entries: name or path:name")
    args = parser.parse_args()

    changed_raw = run(["git", "diff", "--name-only", f"{args.base}...{args.head}", "--", "EvmEquivalence"])
    changed_files = [p for p in changed_raw.splitlines() if p.endswith(".lean")]

    if not changed_files:
        print("signature gate: no changed Lean files under EvmEquivalence")
        return 0

    allow = load_allowlist(args.allowlist)
    unexpected: list[tuple[str, str, str, str]] = []
    expected_changes: list[tuple[str, str]] = []

    for path in changed_files:
        base_src = git_show(args.base, path)
        head_src = git_show(args.head, path)
        if not base_src or not head_src:
            continue
        base_decls = extract_decls(base_src)
        head_decls = extract_decls(head_src)
        for name in sorted(set(base_decls) & set(head_decls)):
            b = base_decls[name]
            h = head_decls[name]
            if b == h:
                continue
            key = f"{path}:{name}"
            if name in allow or key in allow:
                expected_changes.append((key, h))
                continue
            unexpected.append((path, name, b, h))

    if expected_changes:
        print("signature gate: allowlisted drift")
        for key, sig in expected_changes:
            print(f"  - {key}: {sig}")

    if unexpected:
        print("signature gate failed: unexpected declaration signature drift:")
        for path, name, base_sig, head_sig in unexpected:
            print(f"  - {path}:{name}")
            print(f"    base: {base_sig}")
            print(f"    head: {head_sig}")
        return 1

    print("signature gate passed: no unexpected declaration signature drift")
    return 0


if __name__ == "__main__":
    sys.exit(main())
