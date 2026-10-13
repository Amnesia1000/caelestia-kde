#!/usr/bin/env python3

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

RED = "\033[0;31m"
GREEN = "\033[0;32m"
BOLD = "\033[1m"
RESET = "\033[0m"

BASH_INTERP_RE = re.compile(
    r"#"
    r"|%"
    r"|:-|:=|:\?|:\+"
    r"|:[0-9]"
    r"|\^"
    r"|,$"
    r"|\[[@*]\]"
)


def _unescaped_interpolations(src: str) -> list[tuple[int, str, bool]]:
    found: list[tuple[int, str, bool]] = []
    in_template = False
    line_start = 0
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        if ch == "\\" and i + 1 < n:
            i += 2
            continue
        if ch == "\n":
            line_start = i + 1
            i += 1
            continue
        if ch == "`":
            in_template = not in_template
            i += 1
            continue
        if in_template and ch == "$" and i + 1 < n and src[i + 1] == "{":
            body_start = i + 2
            j = body_start
            depth = 1
            while j < n and depth > 0:
                if src[j] == "{":
                    depth += 1
                elif src[j] == "}":
                    depth -= 1
                j += 1
            body = src[body_start:j - 1]
            in_comment = src[line_start:i].lstrip().startswith("#")
            if in_comment or BASH_INTERP_RE.search(body):
                found.append((i, body, in_comment))
            i = j
            continue
        i += 1
    return found


def _line_col(src: str, offset: int) -> tuple[int, int]:
    return src.count("\n", 0, offset) + 1, offset - src.rfind("\n", 0, offset)


def _backticks_in_template_comments(src: str) -> list[int]:
    found: list[int] = []
    in_template = False
    line_start = 0
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        if ch == "\\" and i + 1 < n:
            i += 2
            continue
        if ch == "\n":
            line_start = i + 1
            i += 1
            continue
        if ch == "`":
            if in_template and src[line_start:i].lstrip().startswith("#"):
                found.append(i)
            in_template = not in_template
            i += 1
            continue
        i += 1
    return found


def check_file(path: Path) -> list[str]:
    try:
        src = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        return [f"{path}: cannot read file: {exc}"]

    errors: list[str] = []
    for offset, body, in_comment in _unescaped_interpolations(src):
        line, col = _line_col(src, offset)
        if in_comment:
            errors.append(
                f"{path}:{line}:{col}: unescaped ${{{body}}} inside a comment within a "
                "template literal - QML interpolates it before bash sees the script, "
                "and a body like this is not valid QML, so the file stops parsing; "
                f"write \\${{{body}}} or reword the comment"
            )
        else:
            errors.append(
                f"{path}:{line}:{col}: unescaped bash parameter expansion "
                f"${{{body}}} inside a template literal - escape it as \\${{{body}}}"
            )
    for offset in _backticks_in_template_comments(src):
        line, col = _line_col(src, offset)
        errors.append(
            f"{path}:{line}:{col}: backtick inside a comment within a template literal - "
            "it ends the literal and the file stops parsing; drop it or write it as \\`"
        )
    return errors


def main(argv: list[str]) -> int:
    if argv:
        targets: list[Path] = []
        for arg in argv:
            p = Path(arg)
            if not p.is_absolute():
                p = ROOT / p
            targets.append(p)
    else:
        targets = [ROOT]

    files: list[Path] = []
    for t in targets:
        if t.is_dir():
            files.extend(sorted(t.rglob("*.qml")))
        elif t.suffix == ".qml":
            files.append(t)

    print(f"{BOLD}=== QML template interpolation check ({len(files)} files) ==={RESET}")
    all_errors: list[str] = []
    for f in files:
        all_errors.extend(check_file(f))

    for err in all_errors:
        print(f"{RED}[ERR]{RESET}  {err}")

    print()
    if all_errors:
        print(f"{BOLD}{RED}{len(all_errors)} unescaped bash interpolation(s) found.{RESET}")
        return 1
    print(f"{BOLD}{GREEN}No unescaped bash interpolation in QML template literals.{RESET}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
