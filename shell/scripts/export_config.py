#!/usr/bin/env python3
"""Export shell configuration to YAML (shell.yaml next to shell.json)."""

import json
import os
import sys

errors = []


def load_json(path, default):
    if not os.path.exists(path):
        return default
    try:
        with open(path) as f:
            return json.load(f)
    except Exception as e:
        errors.append(f"{path}: {e}")
        return default


def scalar(v):
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    # All strings are quoted so a reload never coerces them
    # ("1.0" stays a string, "007" keeps its zeros, "no" is not False).
    t = str(v)
    return '"' + t.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def dump(v, ind):
    pad = "  " * ind
    if isinstance(v, dict):
        if not v:
            return "{}\n"
        out = ""
        for k, item in v.items():
            if isinstance(item, (dict, list)):
                nested = dump(item, ind + 1)
                if nested in ("[]\n", "{}\n"):
                    out += pad + scalar(k) + ": " + nested
                else:
                    out += pad + scalar(k) + ":\n" + nested
            else:
                out += pad + scalar(k) + ": " + scalar(item) + "\n"
        return out
    if isinstance(v, list):
        if not v:
            return "[]\n"
        out = ""
        for item in v:
            if isinstance(item, (dict, list)):
                out += pad + "-\n" + dump(item, ind + 1)
            else:
                out += pad + "- " + scalar(item) + "\n"
        return out
    return scalar(v)


def main():
    config_dir, state_dir, plugins_json = sys.argv[1:4]
    out = {}
    out["shell"] = load_json(os.path.join(config_dir, "shell.json"), {})
    out["keybinds"] = load_json(os.path.join(config_dir, "keybinds.json"), {})
    out["cli"] = load_json(os.path.join(config_dir, "cli.json"), {})
    out["notes"] = load_json(os.path.join(state_dir, "notes_tab.json"), [])
    monitors = {}
    mon_dir = os.path.join(config_dir, "monitors")
    if os.path.isdir(mon_dir):
        for name in sorted(os.listdir(mon_dir)):
            v = load_json(os.path.join(mon_dir, name, "shell.json"), None)
            if v is not None:
                monitors[name] = v
    out["monitors"] = monitors
    try:
        out["plugins"] = json.loads(plugins_json)
    except Exception as e:
        errors.append(f"plugins: {e}")
        out["plugins"] = []
    if errors:
        for e in errors:
            print(f"export_config: {e}", file=sys.stderr)
        sys.exit(1)
    with open(os.path.join(config_dir, "shell.yaml"), "w") as f:
        f.write(dump(out, 0))
    print("DONE")


main()
