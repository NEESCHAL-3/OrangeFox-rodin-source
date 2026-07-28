#!/usr/bin/env python3

import argparse
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import List, Optional


def git_head(path: Path) -> Optional[str]:
    result = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "HEAD"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify every project in a pinned repo manifest."
    )
    parser.add_argument("top", type=Path)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()

    projects = ET.parse(args.manifest).getroot().findall("project")
    failures: List[str] = []

    for project in projects:
        relative = project.get("path") or project.get("name")
        expected = project.get("revision")
        if not relative or not expected:
            failures.append("manifest project is missing path/name or revision")
            continue

        actual = git_head(args.top / relative)
        if actual is None:
            failures.append(f"missing git project: {relative}")
        elif actual != expected:
            failures.append(f"{relative}: {actual} (expected {expected})")

    if failures:
        for failure in failures:
            print(f"ERROR: source revision mismatch: {failure}", file=sys.stderr)
        print(
            f"Pinned source verification failed for {len(failures)} of "
            f"{len(projects)} projects",
            file=sys.stderr,
        )
        return 1

    print(f"Pinned source verification passed: {len(projects)} projects")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
