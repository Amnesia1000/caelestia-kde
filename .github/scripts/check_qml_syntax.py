#!/usr/bin/env python3

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PAIRS = {")": "(", "]": "[", "}": "{"}

REGEX_KEYWORDS = {
    "return", "case", "typeof", "instanceof", "in", "of", "new", "delete",
    "void", "throw", "yield", "await", "else", "do",
}

DIVISION_PREV = set(")]}\"'`")


def _prev_significant(text: str, i: int) -> tuple[str, str]:
    j = i - 1
    while j >= 0 and text[j] in " \t\r\n":
        j -= 1
    if j < 0:
        return "", ""
    c = text[j]
    if c.isalnum() or c in "_$":
        k = j
        while k >= 0 and (text[k].isalnum() or text[k] in "_$"):
            k -= 1
        return c, text[k + 1 : j + 1]
    return c, ""


def skip_template(text: str, i: int, line: int) -> tuple[int, int]:
    n = len(text)
    i += 1
    while i < n:
        c = text[i]
        if c == "\\":
            i += 2
            continue
        if c == "`":
            return i + 1, line
        if text.startswith("${", i):
            i, line = _skip_template_expr(text, i + 2, line)
            continue
        if c == "\n":
            line += 1
        i += 1
    return i, line


def _skip_template_expr(text: str, i: int, line: int) -> tuple[int, int]:
    n = len(text)
    depth = 1
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        if text.startswith("/*", i):
            i += 2
            while i + 1 < n and text[i : i + 2] != "*/":
                if text[i] == "\n":
                    line += 1
                i += 1
            i += 2
            continue
        if c in "\"'":
            quote = c
            i += 1
            while i < n:
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == quote:
                    i += 1
                    break
                i += 1
            continue
        if c == "`":
            i, line = skip_template(text, i, line)
            continue
        if c == "/":
            if _is_regex_start(text, i):
                i, line = _skip_regex(text, i, line)
                continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i + 1, line
        i += 1
    return i, line


def _is_regex_start(text: str, i: int) -> bool:
    prev_char, prev_word = _prev_significant(text, i)
    if prev_word:
        return prev_word in REGEX_KEYWORDS
    return prev_char not in DIVISION_PREV


def _skip_regex(text: str, i: int, line: int) -> tuple[int, int]:
    n = len(text)
    i += 1
    in_class = False
    while i < n:
        c = text[i]
        if c == "\n":
            break
        if c == "\\":
            i += 2
            continue
        if c == "[":
            in_class = True
        elif c == "]":
            in_class = False
        elif c == "/" and not in_class:
            i += 1
            while i < n and text[i].isalpha():
                i += 1
            return i, line
        i += 1
    return i, line


def scan(text: str) -> list[str]:
    issues: list[str] = []
    stack: list[tuple[str, int, bool]] = []
    i = 0
    n = len(text)
    line = 1
    pending_word: str | None = None
    pending_at_stmt_start = False
    pending_qtobject = False

    while i < n:
        c = text[i]

        if c == "\n":
            line += 1
            i += 1
            continue

        if c in "\"'":
            quote = c
            i += 1
            while i < n:
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == "\n":
                    line += 1
                if text[i] == quote:
                    i += 1
                    break
                i += 1
            continue

        if c == "`":
            i, line = skip_template(text, i, line)
            continue

        if text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue

        if text.startswith("/*", i):
            i += 2
            while i + 1 < n and text[i : i + 2] != "*/":
                if text[i] == "\n":
                    line += 1
                i += 1
            i += 2
            continue

        if c == "/":
            if _is_regex_start(text, i):
                i, line = _skip_regex(text, i, line)
            else:
                i += 1
            continue

        if text.startswith("component", i):
            prev = text[i - 1] if i > 0 else ""
            after = text[i + 9] if i + 9 < n else ""
            if not (prev.isalnum() or prev == "_") and not (after.isalnum() or after == "_"):
                if not stack:
                    issues.append(
                        f"line {line}: top-level inline `component` declaration - "
                        "inline components must be declared inside an object"
                    )
            i += 9
            continue

        if c.isalpha() or c == "_":
            j = i
            while j < n and (text[j].isalnum() or text[j] == "_"):
                j += 1
            word = text[i:j]
            k = i - 1
            while k >= 0 and text[k] in " \t":
                k -= 1
            prev = text[k] if k >= 0 else ""
            pending_at_stmt_start = prev in ("", "\n", ";", "{", "}")
            pending_word = word
            pending_qtobject = word == "QtObject"
            i = j
            continue

        if c in "([{":
            if c == "{":
                if pending_qtobject:
                    if pending_at_stmt_start and stack and stack[-1][2]:
                        issues.append(
                            f"line {line}: object 'QtObject' declared as a child of "
                            "QtObject, which has no default property"
                        )
                    stack.append((c, line, True))
                else:
                    if (
                        pending_word is not None
                        and pending_at_stmt_start
                        and pending_word[:1].isupper()
                        and stack
                        and stack[-1][2]
                    ):
                        issues.append(
                            f"line {line}: object '{pending_word}' declared as a child of "
                            "QtObject, which has no default property"
                        )
                    stack.append((c, line, False))
            else:
                stack.append((c, line, False))
            pending_word = None
            pending_at_stmt_start = False
            pending_qtobject = False
            i += 1
            continue

        if c in ")]}":
            if not stack:
                issues.append(f"line {line}: unmatched closing '{c}'")
            else:
                opener, opened, _qtobj = stack.pop()
                if opener != PAIRS[c]:
                    issues.append(
                        f"line {line}: closing '{c}' does not match "
                        f"'{opener}' opened on line {opened}"
                    )
            pending_word = None
            pending_at_stmt_start = False
            pending_qtobject = False
            i += 1
            continue

        if c not in " \t\r":
            pending_word = None
            pending_at_stmt_start = False
            pending_qtobject = False
        i += 1

    for opener, opened, _qtobj in stack:
        issues.append(f"line {opened}: unclosed '{opener}'")

    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description="Structural QML syntax check")
    parser.add_argument(
        "--source-root",
        default="shell",
        help="directory to scan for .qml files (default: shell)",
    )
    args = parser.parse_args()

    root = Path(args.source_root)
    if not root.is_dir():
        print(f"error: source root {root} is not a directory", file=sys.stderr)
        return 2

    failures = 0
    for qml_file in sorted(root.rglob("*.qml")):
        text = qml_file.read_text(encoding="utf-8")
        for issue in scan(text):
            print(f"{qml_file.as_posix()}: {issue}", file=sys.stderr)
            failures += 1

    if failures:
        print(f"QML syntax check failed: {failures} issue(s)", file=sys.stderr)
        return 1
    print("QML syntax check passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
