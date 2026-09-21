#!/usr/bin/env python3
"""Verify a RotaAssist addon directory or release ZIP without loading WoW.

The check follows active TOC entries and every nested XML Script/Include entry,
using case-sensitive archive paths. It also validates the optional SHA256SUMS
manifest emitted by package_release.ps1.
"""

from __future__ import annotations

import argparse
import hashlib
import posixpath
import re
import sys
import zipfile
from pathlib import Path, PurePosixPath
from xml.etree import ElementTree


ADDON = "RotaAssist"
FORBIDDEN_DIRS = {
    ".git", ".github", ".svn", ".hg", ".vscode", ".idea", ".claude",
    ".agents", "tests", "test", "__tests__", "training", "scripts",
    "node_modules", "__pycache__", "build", "dist", "evals",
}
FORBIDDEN_SUFFIXES = {
    ".py", ".pyc", ".pyo", ".sh", ".ps1", ".bat", ".cmd", ".zip",
    ".7z", ".tar", ".gz", ".rar", ".bak", ".orig", ".rej", ".swp",
    ".tmp", ".log", ".csv", ".ipynb", ".pkl", ".joblib",
}
REQUIRED_LOADED = {
    "Libs/LibStub/LibStub.lua",
    "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
    "Libs/AceAddon-3.0/AceAddon-3.0.lua",
    "Libs/AceDB-3.0/AceDB-3.0.lua",
    "Libs/AceEvent-3.0/AceEvent-3.0.lua",
    "Libs/AceLocale-3.0/AceLocale-3.0.lua",
    "Core/Init.lua",
}


class VerificationError(RuntimeError):
    pass


class Payload:
    def __init__(self, names: list[str], reader):
        self.names = names
        self.name_set = set(names)
        self.folded: dict[str, list[str]] = {}
        for name in names:
            self.folded.setdefault(name.casefold(), []).append(name)
        self._reader = reader

    def read(self, name: str) -> bytes:
        return self._reader(name)

    def require_exact(self, name: str, source: str) -> None:
        if name in self.name_set:
            return
        candidates = self.folded.get(name.casefold(), [])
        if candidates:
            raise VerificationError(
                f"case mismatch from {source}: expected {name!r}, found {candidates[0]!r}"
            )
        raise VerificationError(f"missing reference from {source}: {name}")


def clean_relative(base: str, reference: str) -> str:
    reference = reference.strip().replace("\\", "/")
    if not reference:
        raise VerificationError(f"empty file reference below {base or '.'}")
    if reference.startswith("/") or re.match(r"^[A-Za-z]:", reference):
        raise VerificationError(f"absolute file reference is not allowed: {reference}")
    combined = posixpath.normpath(posixpath.join(base, reference))
    if combined == ".." or combined.startswith("../"):
        raise VerificationError(f"file reference escapes addon root: {reference}")
    return combined


def load_archive(path: Path) -> tuple[Payload, zipfile.ZipFile]:
    archive = zipfile.ZipFile(path, "r")
    all_entries = archive.infolist()
    if not all_entries:
        archive.close()
        raise VerificationError("archive contains no files")
    for info in all_entries:
        name = info.filename
        if "\\" in name:
            archive.close()
            raise VerificationError(f"ZIP entry uses backslash separators: {name}")
        pure = PurePosixPath(name)
        if (
            pure.is_absolute()
            or ".." in pure.parts
            or any(":" in part for part in pure.parts)
            or pure.parts[0] != ADDON
        ):
            archive.close()
            raise VerificationError(f"unsafe or unexpected ZIP root: {name}")
    raw_names = [info.filename for info in all_entries if not info.is_dir()]
    if not raw_names:
        archive.close()
        raise VerificationError("archive contains no files")
    names = [name[len(ADDON) + 1 :] for name in raw_names]
    if len(names) != len(set(names)):
        archive.close()
        raise VerificationError("archive contains duplicate file entries")
    payload = Payload(names, lambda name: archive.read(f"{ADDON}/{name}"))
    return payload, archive


def load_directory(path: Path) -> Payload:
    if not path.is_dir():
        raise VerificationError(f"addon directory does not exist: {path}")
    files = sorted(item for item in path.rglob("*") if item.is_file())
    names = [item.relative_to(path).as_posix() for item in files]
    by_name = dict(zip(names, files))
    return Payload(names, lambda name: by_name[name].read_bytes())


def check_payload_hygiene(payload: Payload) -> None:
    case_groups = [items for items in payload.folded.values() if len(items) > 1]
    if case_groups:
        raise VerificationError(f"case-colliding payload paths: {case_groups[0]}")
    for name in payload.names:
        parts = PurePosixPath(name).parts
        if any(part in FORBIDDEN_DIRS for part in parts[:-1]):
            raise VerificationError(f"development directory in payload: {name}")
        if Path(parts[-1]).suffix.lower() in FORBIDDEN_SUFFIXES:
            raise VerificationError(f"development file in payload: {name}")


def parse_load_graph(payload: Payload) -> tuple[list[str], set[str]]:
    toc_name = f"{ADDON}.toc"
    payload.require_exact(toc_name, "archive root")
    toc_text = payload.read(toc_name).decode("utf-8-sig")
    ordered_lua: list[str] = []
    loaded: set[str] = set()
    toc_entries: list[tuple[str, str]] = []

    for line_number, raw in enumerate(toc_text.splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        name = clean_relative("", line)
        if PurePosixPath(name).suffix.lower() not in {".lua", ".xml"}:
            raise VerificationError(f"unsupported TOC entry at line {line_number}: {line}")
        toc_entries.append((name, f"{toc_name}:{line_number}"))

    visited_xml: set[str] = set()
    active_xml: set[str] = set()

    def expand(name: str, source: str) -> None:
        payload.require_exact(name, source)
        loaded.add(name)
        suffix = PurePosixPath(name).suffix.lower()
        if suffix == ".lua":
            ordered_lua.append(name)
            return
        if name in active_xml:
            raise VerificationError(f"XML include cycle detected at {name}")
        if name in visited_xml:
            return
        active_xml.add(name)
        try:
            root = ElementTree.fromstring(payload.read(name))
        except ElementTree.ParseError as exc:
            raise VerificationError(f"invalid XML in {name}: {exc}") from exc
        base = posixpath.dirname(name)
        for element in root.iter():
            tag = element.tag.rsplit("}", 1)[-1]
            if tag not in {"Script", "Include"}:
                continue
            reference = element.attrib.get("file")
            if reference is None:
                raise VerificationError(f"{name} has <{tag}> without a file attribute")
            child = clean_relative(base, reference)
            expected_suffix = ".lua" if tag == "Script" else ".xml"
            if PurePosixPath(child).suffix.lower() != expected_suffix:
                raise VerificationError(f"{name} <{tag}> has unexpected target: {reference}")
            expand(child, name)
        active_xml.remove(name)
        visited_xml.add(name)

    for name, source in toc_entries:
        expand(name, source)

    missing_required = sorted(REQUIRED_LOADED - loaded)
    if missing_required:
        raise VerificationError(
            "required runtime files are not in the TOC/XML load graph: "
            + ", ".join(missing_required)
        )
    return ordered_lua, loaded


def verify_manifest(payload: Payload, required: bool) -> int:
    manifest_name = "SHA256SUMS.txt"
    if manifest_name not in payload.name_set:
        if required:
            raise VerificationError("SHA256SUMS.txt is missing")
        return 0
    lines = payload.read(manifest_name).decode("utf-8").splitlines()
    declared: dict[str, str] = {}
    for line_number, line in enumerate(lines, start=1):
        if not line.strip():
            continue
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        if not match:
            raise VerificationError(f"invalid SHA256SUMS.txt line {line_number}")
        digest, name = match.groups()
        payload.require_exact(name, f"SHA256SUMS.txt:{line_number}")
        if name == manifest_name or name in declared:
            raise VerificationError(f"invalid duplicate/self manifest entry: {name}")
        declared[name] = digest
    expected = payload.name_set - {manifest_name}
    if set(declared) != expected:
        missing = sorted(expected - set(declared))
        extra = sorted(set(declared) - expected)
        raise VerificationError(f"manifest coverage mismatch; missing={missing}, extra={extra}")
    for name, expected_digest in declared.items():
        actual = hashlib.sha256(payload.read(name)).hexdigest()
        if actual != expected_digest:
            raise VerificationError(f"SHA-256 mismatch for {name}")
    return len(declared)


def main() -> int:
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--archive", type=Path)
    source.add_argument("--addon-dir", type=Path)
    parser.add_argument("--require-manifest", action="store_true")
    parser.add_argument("--print-lua-order", action="store_true")
    args = parser.parse_args()

    archive = None
    try:
        if args.archive:
            payload, archive = load_archive(args.archive.resolve())
        else:
            payload = load_directory(args.addon_dir.resolve())
        check_payload_hygiene(payload)
        ordered_lua, loaded = parse_load_graph(payload)
        manifest_count = verify_manifest(payload, args.require_manifest)
        if args.print_lua_order:
            print("\n".join(ordered_lua))
        else:
            print(
                f"PASS: {len(payload.names)} files; {len(loaded)} TOC/XML-loaded files; "
                f"{len(ordered_lua)} Lua load steps; {manifest_count} manifest hashes"
            )
        return 0
    except (OSError, UnicodeError, zipfile.BadZipFile, VerificationError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    finally:
        if archive is not None:
            archive.close()


if __name__ == "__main__":
    raise SystemExit(main())
