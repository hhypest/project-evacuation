#!/usr/bin/env python3
"""Check repository Markdown links, anchors and the documentation migration map.

Run from any directory: python tools/check_docs.py
Python 3.10+ and its standard library are required. External URLs are reported, not fetched.
"""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent


def prose(text: str) -> str:
    """Ignore fenced/indented examples; preserve line numbers for diagnostics."""
    result: list[str] = []
    fence = ""
    for line in text.splitlines():
        marker = re.match(r"^\s{0,3}(`{3,}|~{3,})", line)
        if marker:
            if not fence:
                fence = marker[1][0]
            elif marker[1][0] == fence:
                fence = ""
            result.append("")
        else:
            result.append("" if fence or line.startswith("    ") or line.startswith("\t") else line)
    return "\n".join(result)


def slug(title: str) -> str:
    title = html.unescape(re.sub(r"<[^>]*>", "", title))
    title = re.sub(r"!?\[([^\]]+)\]\([^)]*\)", r"\1", title)
    return "".join(c for c in title.lower() if c.isalnum() or c in "_- ").replace(" ", "-")


def anchors(text: str) -> set[str]:
    result: set[str] = set()
    counts: dict[str, int] = {}
    text = prose(text)
    for line in text.splitlines():
        m = re.match(r"^#{1,6}\s+(.+?)(?:\s+#+)?$", line)
        if m:
            key = slug(m[1])
            n = counts.get(key, 0)
            counts[key] = n + 1
            result.add(key + (f"-{n}" if n else ""))
    result.update(re.findall(r'<a\s+(?:id|name)=[\"\']([^\"\']+)[\"\']', text))
    return result


def links(text: str) -> list[tuple[int, str]]:
    text = prose(text)
    found: list[tuple[int, str]] = []
    # Inline links/images, optional titles, escaped parentheses and angle destinations.
    pattern = r'!?\[[^\n]*?\]\(\s*(<[^>]+>|(?:\\.|[^\s()]|\([^()]*\))+)\s*(?:[\"\'][^\n]*?[\"\'])?\s*\)'
    for match in re.finditer(pattern, text):
        found.append((text.count("\n", 0, match.start()) + 1, match[1].strip("<>")))
    for match in re.finditer(r'^\s{0,3}\[[^\]]+\]:\s*(<[^>]+>|\S+)', text, re.M):
        found.append((text.count("\n", 0, match.start()) + 1, match[1].strip("<>")))
    return found


def check() -> tuple[list[str], dict[str, object]]:
    files = sorted(p for p in ROOT.rglob("*.md") if not any(part in {".git", ".godot", "work", "builds"} for part in p.relative_to(ROOT).parts))
    cache = {p: anchors(p.read_text(encoding="utf-8")) for p in files}
    errors: list[str] = []
    external: set[str] = set()
    count = 0
    for file in files:
        for line, raw in links(file.read_text(encoding="utf-8")):
            raw = re.sub(r"\\([() ])", r"\1", html.unescape(raw))
            url = urlsplit(raw)
            if url.scheme or url.netloc:
                if url.scheme in {"https", "http"}:
                    external.add(raw)
                continue
            count += 1
            path = unquote(url.path)
            target = (file.parent / path).resolve() if path else file
            where = f"{file.relative_to(ROOT)}:{line}"
            if not target.is_relative_to(ROOT):
                errors.append(f"{where}: link escapes repository: {raw}")
            elif not target.exists():
                errors.append(f"{where}: missing path: {raw}")
            elif url.fragment and target.suffix.lower() == ".md":
                fragment = unquote(url.fragment)
                if fragment not in cache.get(target, set()):
                    errors.append(f"{where}: missing anchor: {raw}")
    mapping_file = ROOT / "docs/maintenance/migration-map.json"
    old_anchors = 0
    if mapping_file.exists():
        mapping = json.loads(mapping_file.read_text(encoding="utf-8"))
        for item in mapping["files"]:
            source = ROOT / item["source"]
            if not source.exists():
                errors.append(f"migration: missing old path {item['source']}")
            for anchor, dest in item["headings"].items():
                old_anchors += 1
                if anchor not in cache.get(source, set()):
                    errors.append(f"migration: old anchor lost: {item['source']}#{anchor}")
                target = ROOT / dest["destination"]
                if dest["anchor"] not in cache.get(target, set()):
                    errors.append(f"migration: missing destination: {dest['destination']}#{dest['anchor']}")
    return errors, {"markdown_files": len(files), "local_links": count, "preserved_anchors": old_anchors, "external_urls": sorted(external)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--external-list", action="store_true", help="print external URLs for a separate network check")
    args = parser.parse_args()
    errors, report = check()
    for error in errors:
        print(error, file=sys.stderr)
    urls = report.pop("external_urls")
    print(json.dumps({**report, "external_urls": len(urls), "errors": len(errors)}, ensure_ascii=False))
    if args.external_list:
        for url in urls:
            print(url)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
