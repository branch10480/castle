#!/usr/bin/env python
from __future__ import annotations

import argparse
from pathlib import Path


def load_summary(summary: str | None, summary_file: str | None) -> str:
    if summary_file:
        return Path(summary_file).read_text()
    if summary is None:
        raise SystemExit("--summary or --summary-file is required")
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description="Insert summary under '## 概要' in PR template")
    parser.add_argument("--template", required=True)
    parser.add_argument("--summary")
    parser.add_argument("--summary-file")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    template_path = Path(args.template)
    text = template_path.read_text()
    summary_text = load_summary(args.summary, args.summary_file)

    marker = "## 概要"
    if marker in text:
        before, after = text.split(marker, 1)
        new_text = before + marker + "\n" + summary_text + after
    else:
        new_text = text + "\n\n" + marker + "\n" + summary_text

    Path(args.out).write_text(new_text)


if __name__ == "__main__":
    main()
