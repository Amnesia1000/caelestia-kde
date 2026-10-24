#!/usr/bin/env python3
"""Report what a panel says it can display, from its EDID.

KScreen accepts any HDR request and keeps it in its config whether or not the panel can
show it, so the shell cannot learn the capability from KScreen. The EDID can: a panel that
does HDR10 carries BT.2020 colourimetry and an HDR Static Metadata block whose transfer
functions include SMPTE ST 2084 (PQ). Anything less is not a screen worth offering the
switch on.

The script is deliberately dependency-free: `edid-decode` is not installed everywhere, and
this only needs two data blocks.
"""

import glob
import json
import os
import sys

CTA_EXTENSION = 0x02
COLORIMETRY = 0x05
HDR_STATIC_METADATA = 0x06

# EDID byte 0x14, bits 6-4: bit depth per primary, as the display reports it.
BIT_DEPTHS = {0: 0, 1: 6, 2: 8, 3: 10, 4: 12, 5: 14, 6: 16}


def edid_paths(output_name):
    """Every sysfs path that can hold this output's EDID, most specific first."""
    return [
        f"/sys/class/drm/card*-{output_name}/edid",
        f"/sys/class/drm/{output_name}/edid",
    ]


def read_edid(output_name):
    for pattern in edid_paths(output_name):
        for path in sorted(glob.glob(pattern)):
            try:
                with open(path, "rb") as handle:
                    data = handle.read()
            except OSError:
                continue
            if len(data) >= 128 and data[:8] == b"\x00\xff\xff\xff\xff\xff\xff\x00":
                return data
    return b""


def data_blocks(block):
    """The CTA-861 data blocks of one extension block, as (tag, payload) pairs."""
    if len(block) < 4 or block[0] != CTA_EXTENSION:
        return

    end = min(block[2], len(block))
    position = 4
    while position < end:
        header = block[position]
        length = header & 0x1F
        payload = block[position + 1:position + 1 + length]
        if len(payload) < length:
            return
        yield (header >> 5) & 0x07, payload
        position += 1 + length


def capabilities(data):
    """What the EDID claims. `hdr` is None when the panel says nothing either way."""
    result = {"bits": 0, "hdr": None, "wcg": None, "maxLuminance": 0}
    if len(data) < 128:
        return result

    result["bits"] = BIT_DEPTHS.get((data[0x14] >> 4) & 0x07, 0)

    for index in range(1, data[126] + 1):
        block = data[index * 128:(index + 1) * 128]
        for tag, payload in data_blocks(block):
            if tag != 7 or not payload:
                continue

            extended = payload[0]
            if extended == COLORIMETRY and len(payload) >= 2:
                # BT.2020 colourimetry, the gamut HDR content is graded in.
                result["wcg"] = bool(payload[1] & 0x05)
            elif extended == HDR_STATIC_METADATA and len(payload) >= 3:
                # Bit 2 of the EOTF byte is SMPTE ST 2084 (PQ, what HDR10 uses), bit 3 is
                # HLG. Either one is a panel that can show an HDR signal; without them the
                # block only describes the SDR range.
                pq = bool(payload[1] & 0x04) or bool(payload[1] & 0x08)
                result["hdr"] = pq
                if len(payload) >= 4 and payload[3]:
                    result["maxLuminance"] = round(50 * 2 ** (payload[3] / 32))

    return result


def describe(edids):
    reports = []
    for output_name, data in edids:
        report = {"output": output_name}
        report.update(capabilities(data))
        reports.append(report)
    return reports


def main(argv):
    if not argv:
        print("usage: panel_capabilities.py [--file PATH] OUTPUT...", file=sys.stderr)
        return 2

    edids = []
    if argv[0] == "--file":
        with open(argv[1], "rb") as handle:
            edids.append((os.path.basename(os.path.dirname(argv[1])) or "edid", handle.read()))
    else:
        for output_name in argv:
            edids.append((output_name, read_edid(output_name)))

    print(json.dumps(describe(edids)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
