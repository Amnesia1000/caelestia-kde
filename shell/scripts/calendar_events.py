#!/usr/bin/env python3
"""Print the upcoming events of one or more iCalendar sources as JSON.

The shell has no PIM stack of its own, so calendars are read straight from the
format everything exports: iCalendar. Google Calendar, Nextcloud, Fastmail and
KDE's own KOrganizer all hand out an `.ics` URL, which is what `--source` takes.

Recurrence is expanded as far as the window needs it (DAILY, WEEKLY, MONTHLY and
YEARLY, with INTERVAL/COUNT/UNTIL/BYDAY/BYMONTHDAY), because a recurring meeting
is the common case and printing only the master event would hide it.

Usage:
    calendar_events.py --days 7 --source 'Work=https://calendar.google.com/…/basic.ics'
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.request
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

CACHE_SECONDS = 900
TIMEOUT_SECONDS = 15
USER_AGENT = "caelestia-shell (+https://github.com/ladybug-me/caelestia-kde)"
WEEKDAYS = ("MO", "TU", "WE", "TH", "FR", "SA", "SU")


def unfold(text: str) -> list[str]:
    """iCalendar folds long lines onto continuations that start with a space."""
    lines: list[str] = []
    for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if raw[:1] in (" ", "\t") and lines:
            lines[-1] += raw[1:]
        else:
            lines.append(raw)
    return lines


def parse_line(line: str) -> tuple[str, dict[str, str], str] | None:
    name_and_params, sep, value = line.partition(":")
    if not sep:
        return None
    parts = name_and_params.split(";")
    name = parts[0].upper()
    params: dict[str, str] = {}
    for param in parts[1:]:
        key, _, param_value = param.partition("=")
        params[key.upper()] = param_value
    return name, params, value


def raw_events(text: str) -> list[dict]:
    """Every VEVENT as `{prop: value}` plus the property parameters."""
    events: list[dict] = []
    current: dict | None = None
    for line in unfold(text):
        if line.upper() == "BEGIN:VEVENT":
            current = {}
            continue
        if line.upper() == "END:VEVENT":
            if current is not None:
                events.append(current)
            current = None
            continue
        if current is None:
            continue
        parsed = parse_line(line)
        if parsed is None:
            continue

        name, params, value = parsed
        if name in ("EXDATE", "RDATE"):
            current.setdefault(name, []).append((params, value))
        elif name not in current:
            current[name] = (params, value)
    return events


def zone_for(params: dict[str, str]) -> ZoneInfo | None:
    tzid = params.get("TZID")
    if not tzid:
        return None
    try:
        return ZoneInfo(tzid)
    except (ZoneInfoNotFoundError, ValueError):
        return None


def parse_moment(params: dict[str, str], value: str, fallback: ZoneInfo | None) -> tuple[datetime, bool]:
    """Turn a DTSTART/DTEND value into an aware datetime, and say if it is a date."""
    value = value.strip()
    if params.get("VALUE", "").upper() == "DATE" or len(value) == 8:
        day = datetime.strptime(value[:8], "%Y%m%d")
        return localize(day, fallback), True
    if value.endswith("Z"):
        return datetime.strptime(value, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc), False
    moment = datetime.strptime(value, "%Y%m%dT%H%M%S")
    return localize(moment, zone_for(params) or fallback), False


def localize(moment: datetime, zone: ZoneInfo | None) -> datetime:
    if moment.tzinfo is not None:
        return moment
    if zone is None:
        return moment.astimezone()
    return moment.replace(tzinfo=zone)


def parse_until(value: str, fallback: ZoneInfo | None) -> datetime:
    if value.endswith("Z"):
        return datetime.strptime(value, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
    if len(value) == 8:
        return localize(datetime.strptime(value, "%Y%m%d"), fallback)
    return localize(datetime.strptime(value[:15], "%Y%m%dT%H%M%S"), fallback)


def parse_rule(rule: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for part in rule.split(";"):
        key, _, value = part.partition("=")
        if key:
            fields[key.upper()] = value
    return fields


def weekdays_of(rule: dict[str, str]) -> list[int]:
    byday = rule.get("BYDAY", "")
    days: list[int] = []
    for token in byday.split(","):
        token = token.strip()
        if not token:
            continue
        token = token[-2:].upper()
        if token in WEEKDAYS:
            days.append(WEEKDAYS.index(token))
    return days


def advance(moment: datetime, rule: dict[str, str]) -> datetime:
    interval = max(1, int(rule.get("INTERVAL", "1") or "1"))
    freq = rule.get("FREQ", "").upper()
    if freq == "DAILY":
        return moment + timedelta(days=interval)
    if freq == "WEEKLY":
        return moment + timedelta(weeks=interval)
    if freq == "MONTHLY":
        month = moment.month - 1 + interval
        year = moment.year + month // 12
        day = min(moment.day, days_in_month(year, month % 12 + 1))
        return moment.replace(year=year, month=month % 12 + 1, day=day)
    if freq == "YEARLY":
        year = moment.year + interval
        day = min(moment.day, days_in_month(year, moment.month))
        return moment.replace(year=year, day=day)
    return moment + timedelta(days=1)


def days_in_month(year: int, month: int) -> int:
    first_next = date(year + (month == 12), month % 12 + 1, 1)
    return (first_next - date(year, month, 1)).days


def expand(start: datetime, rule: dict[str, str], exdates: set[datetime],
           until_window: datetime) -> list[datetime]:
    """The starts of a recurring event that fall before `until_window`.

    BYDAY is only applied to weekly rules, which is where it is actually used;
    a monthly or yearly rule keeps the day of its master event.
    """
    starts: list[datetime] = []
    freq = rule.get("FREQ", "").upper()
    count = int(rule.get("COUNT", "0") or "0")
    until = parse_until(rule["UNTIL"], start.tzinfo) if rule.get("UNTIL") else None
    interval = max(1, int(rule.get("INTERVAL", "1") or "1"))
    byday = weekdays_of(rule) if freq == "WEEKLY" else []
    first_week = start.date() - timedelta(days=start.weekday())

    cursor = start
    produced = 0
    while len(starts) < 400 and cursor <= until_window:
        if until is not None and cursor > until:
            break
        if count and produced >= count:
            break

        if byday:
            if cursor.weekday() not in byday:
                cursor += timedelta(days=1)
                continue
            weeks = (cursor.date() - timedelta(days=cursor.weekday()) - first_week).days // 7
            if weeks % interval:
                cursor += timedelta(days=1)
                continue

        produced += 1
        if cursor not in exdates:
            starts.append(cursor)
        cursor = cursor + timedelta(days=1) if byday else advance(cursor, rule)
    return starts


def build_events(text: str, source_name: str, window_start: datetime,
                 window_end: datetime) -> list[dict]:
    events: list[dict] = []
    for raw in raw_events(text):
        dtstart = raw.get("DTSTART")
        if not dtstart:
            continue
        start_params, start_value = dtstart
        try:
            start, all_day = parse_moment(start_params, start_value, None)
        except ValueError:
            continue

        if "DTEND" in raw:
            try:
                end, _ = parse_moment(raw["DTEND"][0], raw["DTEND"][1], start.tzinfo)
            except ValueError:
                end = start + timedelta(hours=1)
        elif all_day:
            end = start + timedelta(days=1)
        else:
            end = start + timedelta(hours=1)
        # A zero-length entry is a common export slip, and left alone it would fall out
        # of every day of the agenda.
        if end <= start:
            end = start + (timedelta(days=1) if all_day else timedelta(hours=1))

        duration = end - start
        exdates: set[datetime] = set()
        for params, value in raw.get("EXDATE", []):
            for chunk in value.split(","):
                try:
                    exdates.add(parse_moment(params, chunk, start.tzinfo)[0])
                except ValueError:
                    continue

        starts = [start]
        rrule = raw.get("RRULE")
        if rrule:
            starts = expand(start, parse_rule(rrule[1]), exdates, window_end)
        elif start in exdates:
            starts = []

        summary = raw.get("SUMMARY", ({}, ""))[1].replace("\\,", ",").replace("\\n", " ").strip()
        location = raw.get("LOCATION", ({}, ""))[1].replace("\\,", ",").strip()
        uid = raw.get("UID", ({}, ""))[1].strip()

        for occurrence in starts:
            occurrence_end = occurrence + duration
            if occurrence_end < window_start or occurrence > window_end:
                continue
            events.append(
                {
                    "source": source_name,
                    "uid": uid,
                    "summary": summary or "(no title)",
                    "location": location,
                    "allDay": all_day,
                    "startMs": int(occurrence.timestamp() * 1000),
                    "endMs": int(occurrence_end.timestamp() * 1000),
                    "startIso": occurrence.isoformat(),
                    "day": occurrence.strftime("%Y-%m-%d"),
                }
            )
    return events


def read_source(source: str) -> str:
    if source.startswith(("http://", "https://", "webcal://")):
        url = source.replace("webcal://", "https://", 1)
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            return response.read().decode("utf-8", "replace")
    path = Path(os.path.expanduser(source.removeprefix("file://")))
    return path.read_text(encoding="utf-8", errors="replace")


def cached_source(source: str, cache_dir: Path) -> str:
    """Local files are read straight; URLs are cached so a flyout does not re-fetch."""
    if not source.startswith(("http://", "https://", "webcal://")):
        return read_source(source)

    digest = hashlib.sha1(source.encode("utf-8")).hexdigest()[:16]
    cached = cache_dir / f"{digest}.ics"
    if cached.exists() and time.time() - cached.stat().st_mtime < CACHE_SECONDS:
        return cached.read_text(encoding="utf-8", errors="replace")

    text = read_source(source)
    cache_dir.mkdir(parents=True, exist_ok=True)
    cached.write_text(text, encoding="utf-8")
    return text


def default_cache_dir() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    return Path(base) / "caelestia" / "calendar"


def main() -> int:
    parser = argparse.ArgumentParser(description="Print upcoming iCalendar events as JSON")
    parser.add_argument("--days", type=int, default=7, help="how far ahead to look")
    parser.add_argument("--source", action="append", default=[], metavar="NAME=URL",
                        help="a calendar to read, repeatable")
    parser.add_argument("--cache-dir", default=str(default_cache_dir()))
    args = parser.parse_args()

    now = datetime.now().astimezone()
    # From the start of today, not from now: the day's agenda should still list the
    # meeting that already happened, which is what the shell shows when a day is picked.
    window_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    window_end = now + timedelta(days=max(1, args.days))
    cache_dir = Path(os.path.expanduser(args.cache_dir))

    events: list[dict] = []
    errors: list[dict] = []
    for entry in args.source:
        name, sep, location = entry.partition("=")
        if not sep:
            name, location = "Calendar", entry
        try:
            text = cached_source(location.strip(), cache_dir)
            events.extend(build_events(text, name.strip() or "Calendar", window_start, window_end))
        except Exception as error:  # noqa: BLE001 - reported to the UI, never fatal
            errors.append({"source": name, "error": str(error)})

    events.sort(key=lambda event: (event["startMs"], event["summary"]))
    json.dump({"events": events, "errors": errors, "now": int(now.timestamp() * 1000)}, sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
