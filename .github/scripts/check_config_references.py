#!/usr/bin/env python3

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = ROOT / "shell" / "plugin" / "src" / "Caelestia" / "Config"

RED = "\033[0;31m"
GREEN = "\033[0;32m"
BOLD = "\033[1m"
RESET = "\033[0m"

PROP_RE = re.compile(r"CONFIG_(?:GLOBAL_)?(?:ENUM_)?(?:PROPERTY|LIST)\(\s*[^,]+,\s*(\w+)", re.DOTALL)
SUBOBJ_RE = re.compile(r"CONFIG_SUBOBJECT\(\s*(\w+),\s*(\w+)", re.DOTALL)
CLASS_RE = re.compile(r"class\s+(\w+)\s*:\s*public\s+(\w+)")
QPROP_RE = re.compile(r"Q_PROPERTY\(\s*[A-Za-z0-9_:]+\s+(\w+)\s+READ")

FONT_STYLE_RE = re.compile(r"^FONT_STYLE\((\w+),", re.MULTILINE)
FONT_CONFIG_RE = re.compile(r"^FONT_CONFIG\((\w+),\s*(\w+),", re.MULTILINE)
FONT_DEFINITION_LINE_RE = re.compile(r"^.*\\\n", re.MULTILINE)
FONT_DEFINITIONS_MARKER = "#define FONT_STYLE("
MACRO_PROPERTY_RE = re.compile(r"CONFIG_PROPERTY\(\s*\w+\s*,\s*(\w+)\s*,")
MACRO_SUBOBJECT_RE = re.compile(r"CONFIG_SUBOBJECT\(\s*FontConfig##Style##(\w+)\s*,\s*(\w+)\s*\)")
ATTACHED_QPROP_RE = re.compile(
    r'Q_PROPERTY\(\s*const\s+caelestia::config::(\w+)\*\s+(\w+)\s+READ'
)
LEAF = "<leaf>"
METHOD = "<method>"

ROOT_METHODS = {"forScreen", "defaults", "save", "reload", "resetOption", "instance"}


def macro_body(text: str, name: str) -> str:
    lines = text.splitlines()
    for start, line in enumerate(lines):
        if not re.match(rf"#define\s+{name}\(", line):
            continue
        end = start
        while lines[end].endswith("\\") and end + 1 < len(lines):
            end += 1
        return "\n".join(lines[start : end + 1])
    return ""


def parse_headers() -> tuple[dict[str, dict[str, str]], dict[str, str], list[str]]:
    class_members: dict[str, dict[str, str]] = {}
    root_props: dict[str, str] = {}
    problems: list[str] = []

    if not CONFIG_DIR.is_dir():
        return class_members, root_props, problems

    for hdr in sorted(CONFIG_DIR.glob("*.hpp")):
        try:
            text = hdr.read_text(encoding="utf-8")
        except UnicodeDecodeError as exc:
            problems.append(f"{hdr.relative_to(ROOT).as_posix()}: not valid UTF-8 ({exc})")
            continue
        except OSError:
            continue

        if FONT_DEFINITIONS_MARKER in text:
            leaf_props = MACRO_PROPERTY_RE.findall(macro_body(text, "FONT_CONFIG"))
            style_props = MACRO_PROPERTY_RE.findall(macro_body(text, "FONT_STYLE"))
            style_children = MACRO_SUBOBJECT_RE.findall(macro_body(text, "FONT_STYLE"))
            if not leaf_props or not style_props or not style_children:
                problems.append(
                    f"{hdr.relative_to(ROOT).as_posix()}: could not read the FONT_CONFIG/"
                    "FONT_STYLE macros, so the classes they declare went unchecked"
                )

            text = FONT_DEFINITION_LINE_RE.sub("", text)
            for style in FONT_STYLE_RE.findall(text):
                style_cls = f"FontStyle{style}"
                class_members.setdefault(style_cls, {})
                for name in style_props:
                    class_members[style_cls].setdefault(name, LEAF)
                for suffix, key in style_children:
                    cfg_cls = f"FontConfig{style}{suffix}"
                    class_members.setdefault(cfg_cls, {})
                    for name in leaf_props:
                        class_members[cfg_cls].setdefault(name, LEAF)
                    class_members[style_cls].setdefault(key, cfg_cls)

            for style, size in FONT_CONFIG_RE.findall(text):
                cfg_cls = f"FontConfig{style}{size}"
                class_members.setdefault(cfg_cls, {})
                for name in leaf_props:
                    class_members[cfg_cls].setdefault(name, LEAF)

        class_spans: list[tuple[int, str]] = []
        for m in CLASS_RE.finditer(text):
            if m.group(1) == "ConfigObject":
                continue
            class_spans.append((m.start(), m.group(1)))
            class_members.setdefault(m.group(1), {})

        def owner(pos: int) -> str | None:
            current = None
            for span_pos, name in class_spans:
                if span_pos < pos:
                    current = name
                else:
                    break
            return current

        def add_member(owner_name: str | None, name: str, kind: str) -> None:
            if owner_name is not None and name not in class_members[owner_name]:
                class_members[owner_name][name] = kind

        for m in PROP_RE.finditer(text):
            add_member(owner(m.start()), m.group(1), LEAF)
        for m in SUBOBJ_RE.finditer(text):
            add_member(owner(m.start()), m.group(2), m.group(1))
        for m in QPROP_RE.finditer(text):
            if owner(m.start()) not in (None, "Config"):
                add_member(owner(m.start()), m.group(1), LEAF)

        if hdr.name == "configattached.hpp":
            for m in ATTACHED_QPROP_RE.finditer(text):
                root_props[m.group(2)] = m.group(1)
            if re.search(r"Q_PROPERTY\(QString screen", text):
                root_props["screen"] = LEAF

    globals_cls = class_members.get("ConfigRoot", {})
    root_props.update(globals_cls)
    for method in ROOT_METHODS:
        root_props.setdefault(method, METHOD)

    return class_members, root_props, problems


def resolve(class_members: dict[str, dict[str, str]], root_props: dict[str, str], chain: list[str]) -> int | None:
    props = root_props
    for i, name in enumerate(chain):
        if name not in props:
            return i
        member = props[name]
        if member == METHOD:
            return None
        if member == LEAF:
            return None
        if i == len(chain) - 1:
            return None
        props = class_members.get(member, {})
    return None


def strip_comments_and_strings(src: str) -> str:
    out = list(src)
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        if ch == "/" and i + 1 < n and src[i + 1] == "/":
            j = src.find("\n", i)
            if j == -1:
                j = n
            for k in range(i, j):
                out[k] = " "
            i = j
            continue
        if ch == "/" and i + 1 < n and src[i + 1] == "*":
            j = src.find("*/", i + 2)
            if j == -1:
                j = n
            else:
                j += 2
            for k in range(i, j):
                out[k] = " "
            i = j
            continue
        if ch in "\"'":
            quote = ch
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == quote:
                    j += 1
                    break
                j += 1
            for k in range(i, j):
                out[k] = " "
            i = j
            continue
        i += 1
    return "".join(out)


CHAIN_RE = re.compile(r"(?<![A-Za-z0-9_$])(Config|GlobalConfig)\.([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)")


def main() -> int:
    class_members, root_props, problems = parse_headers()

    print(f"{BOLD}=== Config reference check ==={RESET}")
    print(f"Parsed {len(class_members)} config classes, {len(root_props)} root properties")

    if not class_members or not root_props:
        print(f"{RED}Could not parse config headers under {CONFIG_DIR}{RESET}")
        return 1

    errors: list[str] = []
    checked = 0

    for qml in sorted(ROOT.rglob("*.qml")):
        if "build" in qml.parts or ".git" in qml.parts:
            continue
        try:
            src = qml.read_text(encoding="utf-8")
        except UnicodeDecodeError as exc:
            problems.append(f"{qml.relative_to(ROOT).as_posix()}: not valid UTF-8 ({exc})")
            continue
        except OSError:
            continue
        cleaned = strip_comments_and_strings(src)
        for m in CHAIN_RE.finditer(cleaned):
            prefix, chain_text = m.group(1), m.group(2)
            chain = chain_text.split(".")
            checked += 1
            bad = resolve(class_members, root_props, chain)
            if bad is not None:
                missing = chain[bad]
                context = qml.relative_to(ROOT).as_posix()
                line = src.count("\n", 0, m.start()) + 1
                errors.append(
                    f"{context}:{line}: unknown config reference "
                    f"{prefix}.{chain_text} (no property '{missing}'"
                    f"{'' if bad == 0 else ' at this level'})"
                )

    for err in errors:
        print(f"{RED}[ERR]{RESET}  {err}")

    for problem in problems:
        print(f"{RED}[ERR]{RESET}  {problem}")

    print()
    print(f"Checked {checked} config references across QML files.")
    if problems:
        print(f"{BOLD}{RED}{len(problems)} problem(s) in the config sources.{RESET}")
    if errors:
        print(f"{BOLD}{RED}{len(errors)} unknown config reference(s) found.{RESET}")
    if errors or problems:
        return 1
    print(f"{BOLD}{GREEN}All config references resolve.{RESET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
