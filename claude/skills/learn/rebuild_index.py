#!/usr/bin/env python3
"""
rebuild_index.py — `entries/*.html` を scan して index.html の entries-data JSON を再生成する。

Usage:
    python3 rebuild_index.py <repo_root>

例:
    python3 ~/.claude/skills/learn/rebuild_index.py ~/ghq/github.com/branch10480/learnings

各 entry HTML の <head> から以下のメタタグを抽出する:
    <meta name="learning:title"        content="...">
    <meta name="learning:date"         content="YYYY-MM-DD">
    <meta name="learning:tags"         content="tag1, tag2, tag3">
    <meta name="learning:summary"      content="...">
    <meta name="learning:reading-time" content="20">

抽出した結果を JSON 配列にして、index.html 内の
    <script type="application/json" id="entries-data">
        ...
    </script>
ブロックを書き換える。
"""
from __future__ import annotations

import json
import re
import sys
from html import unescape
from pathlib import Path

## クオート種別をキャプチャしてバックリファレンス (\1, \3) で終端マッチさせることで、
## ダブルクオートで囲まれた content の中にシングルクオート (例: "It's") が混じっても
## 途中で打ち切られないようにする。
META_RE = re.compile(
    r'<meta\s+name=(["\'])learning:([\w-]+)\1\s+content=(["\'])(.*?)\3\s*/?>',
    re.IGNORECASE,
)

## id="entries-data" だけで識別する (type 属性の有無や属性順序に依存しない)。
ENTRIES_DATA_RE = re.compile(
    r'(<script\b[^>]*\bid=["\']entries-data["\'][^>]*>)'
    r'(.*?)'
    r'(</script>)',
    re.DOTALL | re.IGNORECASE,
)


def extract_metadata(html_path: Path) -> dict | None:
    """1 つの entry HTML からメタデータを抽出。必須項目欠けは None を返す。"""
    try:
        text = html_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as e:
        print(f"  ! skip {html_path.name}: read error ({e})", file=sys.stderr)
        return None

    head_match = re.search(r"<head[^>]*>(.*?)</head>", text, re.DOTALL | re.IGNORECASE)
    if not head_match:
        ## SKILL.md は learning:* メタタグを <head> 内に置くことを契約している。
        ## <head> がない HTML は規約違反扱いで skip する (本文中の偽メタタグを誤拾いしない)。
        print(f"  ! skip {html_path.name}: <head> not found", file=sys.stderr)
        return None
    head = head_match.group(1)

    meta = {}
    for m in META_RE.finditer(head):
        key = m.group(2).lower()
        val = unescape(m.group(4)).strip()
        meta[key] = val

    required = ("title", "date", "tags", "summary")
    if not all(k in meta and meta[k] for k in required):
        missing = [k for k in required if not meta.get(k)]
        print(
            f"  ! skip {html_path.name}: missing meta {missing}",
            file=sys.stderr,
        )
        return None

    tags = [t.strip().lower() for t in meta["tags"].split(",") if t.strip()]

    return {
        "file": f"entries/{html_path.name}",
        "title": meta["title"],
        "date": meta["date"],
        "tags": tags,
        "summary": meta["summary"],
        "reading": meta.get("reading-time", "—"),
    }


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2

    root = Path(sys.argv[1]).expanduser().resolve()
    entries_dir = root / "entries"
    index_path = root / "index.html"

    if not entries_dir.is_dir():
        print(f"error: {entries_dir} not found", file=sys.stderr)
        return 1
    if not index_path.is_file():
        print(f"error: {index_path} not found", file=sys.stderr)
        return 1

    html_files = sorted(p for p in entries_dir.glob("*.html") if not p.name.startswith("_"))
    print(f"scanning {len(html_files)} entries in {entries_dir}")

    entries: list[dict] = []
    for path in html_files:
        meta = extract_metadata(path)
        if meta:
            entries.append(meta)
            print(f"  + {path.name}  [{', '.join(meta['tags'])}]")

    if not entries:
        print("warning: no valid entries collected", file=sys.stderr)
        if html_files:
            ## 入力 HTML はあるのに 1 件も拾えていない → 何かが壊れている。
            ## 既存 index.html を空配列で上書きせず、人間に気付かせるため exit 1。
            print("error: aborting to protect index.html", file=sys.stderr)
            return 1

    entries.sort(key=lambda e: e["date"], reverse=True)

    json_block = json.dumps(entries, ensure_ascii=False, indent=2)
    new_script = f"\n{json_block}\n"

    index_text = index_path.read_text(encoding="utf-8")
    new_index, count = ENTRIES_DATA_RE.subn(
        ## group(1) = 開き <script ...>, group(3) = </script>
        ## (group(2) は元の中身でこちらは捨てる)
        lambda m: m.group(1) + new_script + m.group(3),
        index_text,
        count=1,
    )

    if count == 0:
        print(
            'error: <script id="entries-data"> block not found in index.html',
            file=sys.stderr,
        )
        return 1

    if new_index == index_text:
        print("index.html: no changes")
    else:
        index_path.write_text(new_index, encoding="utf-8")
        print(f"index.html: updated ({len(entries)} entries)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
