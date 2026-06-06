#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
LINK_RE = re.compile(r"\[\[([^\]|#]+)(?:#[^\]|]+)?(?:\|[^\]]+)?\]\]")
FENCE_RE = re.compile(r"```.*?```", re.DOTALL)

markdown_files = [p for p in ROOT.rglob('*.md') if '.git' not in p.parts]
stems = {p.stem for p in markdown_files}
relative_no_suffix = {str(p.relative_to(ROOT).with_suffix('')) for p in markdown_files}

missing = []
for path in markdown_files:
    text = path.read_text(encoding='utf-8')
    text = FENCE_RE.sub('', text)
    for match in LINK_RE.finditer(text):
        target = match.group(1).strip()
        if target.startswith(('http://', 'https://')):
            continue
        normalized = target.replace('\\', '/')
        if normalized in relative_no_suffix or Path(normalized).name in stems:
            continue
        missing.append((path.relative_to(ROOT), target))

if missing:
    print('Missing Obsidian links:')
    for path, target in missing:
        print(f'- {path}: [[{target}]]')
    sys.exit(1)

print(f'OK: checked {len(markdown_files)} markdown files')
