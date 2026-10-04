#!/usr/bin/env python3
"""Export shell configuration to YAML (shell.yaml next to shell.json)."""

import json
import os
import re
import sys


def load_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return default


def load_text(path):
    try:
        with open(path) as f:
            content = f.read()
        try:
            return json.loads(content)
        except Exception:
            return content
    except Exception:
        return None


def scalar(v):
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    t = str(v)
    if t != "" and re.match(r"^[A-Za-z0-9_.\-]+$", t) and t not in ("null", "true", "false"):
        return t
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
                    out += pad + str(k) + ": " + nested
                else:
                    out += pad + str(k) + ":\n" + nested
            else:
                out += pad + str(k) + ": " + scalar(item) + "\n"
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
    out["shell"] = load_json(os.path.join(config_dir, "caelestia", "shell.json"), {})
    out["keybinds"] = load_json(os.path.join(config_dir, "caelestia", "keybinds.json"), {})
    out["cli"] = load_json(os.path.join(config_dir, "caelestia", "cli.json"), {})
    out["notes"] = load_json(os.path.join(state_dir, "caelestia", "notes_tab.json"), [])
    monitors = {}
    mon_dir = os.path.join(config_dir, "caelestia", "monitors")
    try:
        for name in sorted(os.listdir(mon_dir)):
            entry = os.path.join(mon_dir, name)
            if os.path.isdir(entry):
                v = load_text(os.path.join(entry, "shell.json"))
            else:
                v = load_text(entry)
            if v is not None:
                monitors[name] = v
    except Exception:
        pass
    out["monitors"] = monitors
    try:
        out["plugins"] = json.loads(plugins_json)
    except Exception:
        out["plugins"] = []
    with open(os.path.join(config_dir, "caelestia", "shell.yaml"), "w") as f:
        f.write(dump(out, 0))
    print("DONE")


main()
