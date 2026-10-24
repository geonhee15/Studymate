#!/usr/bin/env python3
"""Splits docs/AMC8_concepts.md into the per-unit lesson files the app reads.

    Resources/Content/amc8/unitN/lessons.md   (## 유닛 N … up to the next unit, verbatim)
    Resources/Content/amc8/common.md          (## 0. 모든 유닛 공통)
    Resources/Content/amc8/cheatsheet.md      (## 부록 …)

Run after editing the concept document; the output is committed so the app never parses docs/ directly.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "docs", "AMC8_concepts.md")
OUT = os.path.join(ROOT, "Resources", "Content", "amc8")

text = open(SRC, encoding="utf-8").read()
parts = re.split(r"(?m)^(?=## )", text)
written = []
for part in parts:
    head = part.split("\n", 1)[0]
    m = re.match(r"## 유닛 (\d+)\.", head)
    body = part.rstrip() + "\n"
    if m:
        n = int(m.group(1))
        d = os.path.join(OUT, f"unit{n}")
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, "lessons.md")
    elif head.startswith("## 0."):
        path = os.path.join(OUT, "common.md")
    elif head.startswith("## 부록"):
        path = os.path.join(OUT, "cheatsheet.md")
    else:
        continue
    with open(path, "w", encoding="utf-8") as f:
        f.write(body)
    written.append(path)
for p in written:
    print("wrote", os.path.relpath(p, ROOT))

# Sanity: every non-empty line of the unit sections must be present in some output file.
joined = "\n".join(open(p, encoding="utf-8").read() for p in written)
start = text.index("## 0.")
missing = [l for l in text[start:].split("\n") if l.strip() and l not in joined]
if missing:
    print("MISSING LINES:", len(missing))
    for l in missing[:10]:
        print("  ", l)
    sys.exit(1)
print("all lines carried over")
