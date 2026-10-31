#!/usr/bin/env python3
"""Read-only checks for HamCare's existing avatar catalogs and PNG assets.

Pending catalog assets are allowed unless their body/color is selected by
--require. This command never changes images, catalogs, or Flutter settings.
"""

import argparse
import csv
import json
from pathlib import Path
import re
import struct
import sys
import zlib


STATES = (
    "happy", "stable", "worried", "alert", "insufficient_data",
    "environment_discomfort", "activity_high", "condition_concerned",
)
COLORS = {
    "syrian": {"golden", "cream", "white", "dark", "dalmatian"},
    "djungarian": {"normal", "sapphire", "pearl", "cream"},
    "roborovski": {"normal", "white_face"},
}
CATALOGS = (
    "assets/avatars/avatar_asset_manifest.csv",
    "assets/avatars/dalmatian_asset_manifest.csv",
)
ILLUSTRATIONS = {"assets/avatars/syrian/golden/analysis_preparing_v1.png"}


def asset_directories(pubspec):
    """Read directory entries in the existing flutter.assets YAML list."""
    directories = set()
    in_flutter = False
    in_assets = False
    for raw in pubspec.splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        if indent == 0:
            in_flutter = line == "flutter:"
            in_assets = False
            continue
        if not in_flutter:
            continue
        if indent == 2 and line.strip() == "assets:":
            in_assets = True
            continue
        if in_assets and indent <= 2:
            in_assets = False
        if in_assets:
            match = re.match(r"\s*-\s+(.+?)\s*$", line)
            if match:
                value = match.group(1).strip("\"'")
                if value.endswith("/"):
                    directories.add(value)
    return directories


def png_metadata(path):
    """Validate PNG structure and chunk CRCs without rewriting or decoding it."""
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("invalid PNG signature")
    offset = 8
    dimensions = None
    alpha_capable = False
    saw_idat = False
    saw_iend = False
    chunk_index = 0
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError("truncated PNG chunk")
        length = struct.unpack_from(">I", data, offset)[0]
        chunk_type = data[offset + 4:offset + 8]
        end = offset + length + 12
        if end > len(data):
            raise ValueError("truncated PNG chunk payload")
        payload = data[offset + 8:end - 4]
        expected_crc = struct.unpack_from(">I", data, end - 4)[0]
        actual_crc = zlib.crc32(chunk_type + payload) & 0xFFFFFFFF
        if expected_crc != actual_crc:
            raise ValueError("PNG chunk CRC mismatch")
        if chunk_index == 0 and chunk_type != b"IHDR":
            raise ValueError("IHDR must be the first PNG chunk")
        if chunk_type == b"IHDR":
            if dimensions is not None or length != 13:
                raise ValueError("invalid or duplicate IHDR")
            width, height, depth, color, compression, filtering, interlace = (
                struct.unpack(">IIBBBBB", payload)
            )
            valid_depths = {
                0: {1, 2, 4, 8, 16}, 2: {8, 16}, 3: {1, 2, 4, 8},
                4: {8, 16}, 6: {8, 16},
            }
            if (not width or not height or depth not in valid_depths.get(color, set())
                    or compression != 0 or filtering != 0 or interlace not in (0, 1)):
                raise ValueError("invalid PNG IHDR fields")
            dimensions = {"width": width, "height": height, "bit_depth": depth,
                          "color_type": color}
            alpha_capable = color in (4, 6)
        elif chunk_type == b"tRNS":
            alpha_capable = True
        elif chunk_type == b"IDAT":
            saw_idat = True
        elif chunk_type == b"IEND":
            if length != 0:
                raise ValueError("invalid IEND payload")
            saw_iend = True
            if end != len(data):
                raise ValueError("unexpected data after IEND")
            break
        offset = end
        chunk_index += 1
    if dimensions is None or not saw_idat or not saw_iend:
        raise ValueError("missing required PNG chunks")
    return {**dimensions, "alpha_capable": alpha_capable, "bytes": len(data)}


def inspect(root, required):
    errors, warnings = [], []
    catalog = {}
    for filename in CATALOGS:
        path = root / filename
        if not path.is_file():
            errors.append(f"Missing catalog: {filename}")
            continue
        with path.open(encoding="utf-8-sig", newline="") as stream:
            reader = csv.DictReader(stream)
            needed = {"body_type", "color_variant", "condition", "asset_path"}
            if not needed.issubset(reader.fieldnames or []):
                errors.append(f"Invalid catalog columns: {filename}")
                continue
            for line_number, row in enumerate(reader, 2):
                body, color, state = (row.get(k, "").strip() for k in
                                      ("body_type", "color_variant", "condition"))
                key = (body, color, state)
                expected = f"assets/avatars/{body}/{color}/{state}.png"
                if color not in COLORS.get(body, set()) or state not in STATES:
                    errors.append(f"Unknown catalog key: {filename}:{line_number}")
                    continue
                if row.get("asset_path", "").strip() != expected:
                    errors.append(f"Unsafe or mismatched catalog path: {filename}:{line_number}")
                    continue
                if key in catalog:
                    errors.append(f"Duplicate catalog row: {body}/{color}/{state}")
                    continue
                catalog[key] = expected
    expected_keys = {(body, color, state) for body, colors in COLORS.items()
                     for color in colors for state in STATES}
    for body, color, state in sorted(expected_keys - set(catalog)):
        errors.append(f"Missing catalog row: {body}/{color}/{state}")
    pubspec = root / "pubspec.yaml"
    directories = asset_directories(pubspec.read_text(encoding="utf-8")) if pubspec.is_file() else set()
    if not pubspec.is_file():
        errors.append("Missing pubspec.yaml")
    present, pending = [], []
    for key, filename in sorted(catalog.items()):
        path = root / filename
        if not path.is_file():
            pending.append(filename)
            continue
        if path.is_symlink():
            errors.append(f"Avatar symlink is not accepted: {filename}")
            continue
        try:
            metadata = png_metadata(path)
        except (ValueError, OSError) as error:
            errors.append(f"Invalid image: {filename}: {error}")
            continue
        directory = path.parent.relative_to(root).as_posix() + "/"
        if directory not in directories:
            errors.append(f"PNG leaf directory is not registered in pubspec: {directory}")
        if not metadata["alpha_capable"]:
            warnings.append(f"No alpha channel/transparency chunk: {filename}")
        if metadata["width"] != metadata["height"]:
            warnings.append(f"Existing non-square canvas (not changed): {filename}")
        present.append({"asset_path": filename, **metadata})
    known_paths = set(catalog.values())
    illustrations = []
    for path in sorted((root / "assets/avatars").rglob("*.png")):
        filename = path.relative_to(root).as_posix()
        if filename in ILLUSTRATIONS:
            illustrations.append(filename)
        elif filename not in known_paths:
            errors.append(f"PNG has no avatar catalog entry: {filename}")
    for pair in required:
        parts = pair.split("/")
        if len(parts) != 2 or parts[1] not in COLORS.get(parts[0], set()):
            errors.append(f"Unknown --require body/color: {pair}")
            continue
        body, color = parts
        directory = f"assets/avatars/{body}/{color}/"
        if directory not in directories:
            errors.append(f"Required leaf directory is not registered in pubspec: {directory}")
        for state in STATES:
            if (body, color, state) not in catalog or not (root / directory / f"{state}.png").is_file():
                errors.append(f"Required avatar is pending: {body}/{color}/{state}.png")
    warnings.append("PNG metadata/CRC checks do not prove visual transparency, artwork quality, or full image decode; review the supplied images before release.")
    return {
        "result": "FAIL" if errors else "PASS",
        "catalog_assets": len(catalog), "present_assets": len(present),
        "pending_assets": len(pending), "required_variants": required,
        "illustrations_excluded": illustrations,
        "images": present, "pending": pending, "warnings": warnings,
        "errors": errors,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent,
                        help="HamCare project directory (default: parent of tool directory)")
    parser.add_argument("--require", action="append", default=[], metavar="BODY/COLOR",
                        help="Require all eight states and leaf registration; may be repeated")
    args = parser.parse_args()
    try:
        result = inspect(args.root.resolve(), args.require)
    except (OSError, csv.Error, UnicodeError) as error:
        result = {"result": "FAIL", "errors": [str(error)]}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["result"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
