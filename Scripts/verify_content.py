#!/usr/bin/env python3
"""Verifies every practice / quiz / test problem under Resources/Content/amc8.

Each problem may carry a "verify" block:
    "verify": {"answer": "<python expr>",                # value of the correct choice
               "choices": ["<expr>", ... 5],              # optional: values of the five choices (fractions, pi, …)
               "methods": ["<expr>", "<expr>"],           # optional: independent computations that must agree
               "note": "…"}
Expressions are evaluated with itertools / math / fractions / collections available (brute force welcome).
Without "choices", the choice strings are parsed as numbers ("$\\frac{5}{12}$", "1,440", "16 - 4\\pi" are understood).

Checks (any failure → exit 1):
    * five choices, all different; exactly one matches the computed answer and it is the lettered one
    * every "methods" expression agrees with the answer (geometry: at least two methods)
    * hints 1–3, solution present, geometry problems carry a figure
    * every figure (inline SVG and unitN/figures/*.svg) stays inside its viewBox, so nothing renders clipped
Run: python3 -I Scripts/verify_content.py [--verbose]
"""
import glob
import itertools
import json
import math
import os
import re
import sys
from collections import Counter
from fractions import Fraction as F
from functools import lru_cache
from math import comb, factorial, gcd, isqrt, perm, pi, sqrt, floor, ceil, lcm

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, "Resources", "Content", "amc8")
VERBOSE = "--verbose" in sys.argv
UNIT_FILTER = None
MOCK_ONLY = "--mock" in sys.argv
for i, a in enumerate(sys.argv):
    if a == "--unit" and i + 1 < len(sys.argv):
        UNIT_FILTER = int(sys.argv[i + 1])
BANDS = {"1-10": 0, "11-15": 1, "16-20": 2, "21-25": 3}


def band_for_number(n):
    return "1-10" if n <= 10 else "11-15" if n <= 15 else "16-20" if n <= 20 else "21-25"


def lesson_ids(unit_dir):
    """### N-M. headings of lessons.md."""
    path = os.path.join(unit_dir, "lessons.md")
    if not os.path.exists(path):
        return []
    return re.findall(r"(?m)^### (\d+-\d+)\.", open(path, encoding="utf-8").read())

ENV = {
    "itertools": itertools, "product": itertools.product, "permutations": itertools.permutations,
    "combinations": itertools.combinations, "combinations_with_replacement": itertools.combinations_with_replacement,
    "math": math, "comb": comb, "perm": perm, "factorial": factorial, "gcd": gcd, "lcm": lcm, "isqrt": isqrt,
    "pi": pi, "sqrt": sqrt, "floor": floor, "ceil": ceil, "F": F, "Fraction": F, "Counter": Counter,
    "lru_cache": lru_cache, "sum": sum, "len": len, "range": range, "set": set, "sorted": sorted, "max": max,
    "min": min, "abs": abs, "all": all, "any": any, "str": str, "int": int, "list": list, "tuple": tuple,
    "enumerate": enumerate, "zip": zip, "map": map, "filter": filter, "round": round, "divmod": divmod,
    "pow": pow, "reversed": reversed, "dict": dict, "bool": bool, "float": float, "frozenset": frozenset,
}


def isprime(n):
    return n >= 2 and all(n % d for d in range(2, isqrt(n) + 1))


def divisors(n):
    return [d for d in range(1, n + 1) if n % d == 0]


def digits(n):
    return [int(c) for c in str(n)]


ENV.update({"isprime": isprime, "divisors": divisors, "digits": digits})


def evaluate(expr):
    """Evaluate a verify expression. Multi-line code may define `result`."""
    if "\n" in expr or expr.lstrip().startswith(("def ", "import ", "from ", "for ", "while ")) or "result" in expr.split("=")[0] if "=" in expr else False:
        ns = dict(ENV)
        exec(expr, ns)
        return ns["result"]
    return eval(expr, dict(ENV))


def parse_choice(text):
    """Turn a choice string into a comparable value, or None when it is not numeric."""
    s = text.strip().strip("$").replace("\\,", "").replace("\\ ", "").replace(",", "").replace("^\\circ", "").replace("°", "")
    s = s.replace("\\left", "").replace("\\right", "").replace("\\%", "").replace("\\text{", "").replace("}", "}")
    s = re.sub(r"\\(d?frac)\{([^{}]+)\}\{([^{}]+)\}", r"((\2)/(\3))", s)
    s = re.sub(r"\\sqrt\{([^{}]+)\}", r"sqrt(\1)", s)
    s = s.replace("\\pi", "*pi").replace("\\cdot", "*").replace("\\times", "*").replace("^", "**").replace("{", "(").replace("}", ")")
    s = re.sub(r"(\d)\s*\(", r"\1*(", s)
    s = re.sub(r"\)\s*(\d)", r")*\1", s)
    s = re.sub(r"(\d|\))\s*sqrt", r"\1*sqrt", s)   # 3\sqrt{2}, \frac{3}{2}\sqrt{2}
    s = s.replace("(*pi", "(pi").replace("/*pi", "/pi").replace("-*pi", "-pi").replace("+*pi", "+pi").replace(" ", "")
    if s.startswith("*pi"):
        s = s[1:]
    s = s.replace("(*", "(")
    try:
        v = eval(s, {"pi": pi, "sqrt": sqrt, "F": F})
    except Exception:
        return None
    try:
        if isinstance(v, float) and abs(v - round(v)) < 1e-9 and "pi" not in s and "sqrt" not in s:
            return F(round(v))
        if isinstance(v, int):
            return F(v)
        if isinstance(v, F):
            return v
        return float(v)
    except Exception:
        return None


def same(a, b):
    if a is None or b is None:
        return False
    if isinstance(a, (int, F)) and isinstance(b, (int, F)):
        return F(a) == F(b)
    try:
        return abs(float(a) - float(b)) < 1e-9
    except Exception:
        return a == b


import xml.etree.ElementTree as ET

def svg_bounds_issues(svg):
    """Every drawn coordinate (and the box a text label occupies) must lie inside the viewBox; otherwise the
    figure renders clipped. Elements under a transform are skipped (two lesson figures use rotate)."""
    try:
        root = ET.fromstring(svg)
    except ET.ParseError as e:
        return [f"SVG 파싱 실패: {e}"]
    vb = root.get("viewBox")
    if not vb:
        return ["viewBox 없음"]
    try:
        x0, y0, w, h = (float(v) for v in vb.replace(",", " ").split())
    except ValueError:
        return [f"viewBox 형식 오류 {vb!r}"]
    x1, y1 = x0 + w, y0 + h
    issues = []

    def check(what, x, y):
        if x < x0 - 0.01 or x > x1 + 0.01 or y < y0 - 0.01 or y > y1 + 0.01:
            issues.append(f"{what} ({x:g}, {y:g})가 viewBox {vb} 밖")

    def walk(el, transformed, inherited):
        tag = el.tag.split("}")[-1]
        transformed = transformed or el.get("transform") is not None
        inherited = {**inherited, **{k: el.get(k) for k in ("font-size", "text-anchor") if el.get(k)}}
        if tag in ("defs", "clipPath", "mask", "marker", "pattern", "symbol", "style", "title"):
            return
        if not transformed:
            def g(k, d="0"):
                try:
                    return float(el.get(k, d))
                except ValueError:
                    return 0.0
            if tag in ("polygon", "polyline"):
                nums = [float(v) for v in re.split(r"[\s,]+", el.get("points", "").strip()) if v]
                for i in range(0, len(nums) - 1, 2):
                    check(tag, nums[i], nums[i + 1])
            elif tag == "line":
                check(tag, g("x1"), g("y1")); check(tag, g("x2"), g("y2"))
            elif tag == "rect":
                check(tag, g("x"), g("y")); check(tag, g("x") + g("width"), g("y") + g("height"))
            elif tag == "circle":
                cx, cy, r = g("cx"), g("cy"), g("r")
                check(tag, cx - r, cy - r); check(tag, cx + r, cy + r)
            elif tag == "ellipse":
                cx, cy, rx, ry = g("cx"), g("cy"), g("rx"), g("ry")
                check(tag, cx - rx, cy - ry); check(tag, cx + rx, cy + ry)
            elif tag == "text":
                fs = float(re.sub(r"[^0-9.]", "", inherited.get("font-size", "12")) or 12)
                text = "".join(el.itertext()).strip()
                def char_w(ch):   # rough system-font advances, in em
                    if ord(ch) > 0x2E80: return 0.95
                    if ch == " ": return 0.28
                    if ch.isalnum(): return 0.56
                    return 0.33
                width = fs * sum(char_w(ch) for ch in text)
                anchor = inherited.get("text-anchor", "start")
                x, y = g("x"), g("y")
                left = x - (width / 2 if anchor == "middle" else width if anchor == "end" else 0)
                what = f"text {text!r}"
                slack = 3   # estimate tolerance
                check(what, left + slack, y - 0.7 * fs + slack); check(what, left + width - slack, y + 0.1 * fs - slack)
            elif tag == "path":
                for cmd, args in re.findall(r"([MLHVCSQTAZmlhvcsqtaz])([^MLHVCSQTAZmlhvcsqtaz]*)", el.get("d", "")):
                    nums = [float(v) for v in re.findall(r"-?\d*\.?\d+(?:e-?\d+)?", args)]
                    if cmd in "MLCSQT":
                        for i in range(0, len(nums) - 1, 2):
                            check("path", nums[i], nums[i + 1])
                    elif cmd == "A":
                        for i in range(0, len(nums) - 6, 7):
                            check("path", nums[i + 5], nums[i + 6])
                    elif cmd == "H":
                        for v in nums:
                            check("path", v, y0)
                    elif cmd == "V":
                        for v in nums:
                            check("path", x0, v)
        for child in el:
            walk(child, transformed, inherited)

    walk(root, False, {})
    return issues


failures = []
total = 0
verified = 0
geometry_logged = 0


def fail(pid, msg):
    failures.append(f"{pid}: {msg}")


paths = sorted(glob.glob(os.path.join(CONTENT, "unit*", "*.json"))) + sorted(glob.glob(os.path.join(CONTENT, "mock", "*.json")))
if UNIT_FILTER is not None:
    paths = [p for p in paths if os.path.basename(os.path.dirname(p)) == f"unit{UNIT_FILTER}"]
if MOCK_ONLY:
    paths = [p for p in paths if os.path.basename(os.path.dirname(p)) == "mock"]
seen_ids = set()
for path in paths:
    rel = os.path.relpath(path, ROOT)
    unit_dir = os.path.dirname(path)
    kind = os.path.basename(path).split(".")[0]      # problems / quiz / test / setN
    is_mock = os.path.basename(unit_dir) == "mock"
    try:
        problems = json.load(open(path, encoding="utf-8"))
    except Exception as e:
        failures.append(f"{rel}: JSON 오류 {e}")
        continue
    if not isinstance(problems, list):
        failures.append(f"{rel}: 최상위가 배열이 아님")
        continue
    known_lessons = None if is_mock else lesson_ids(unit_dir)
    if kind == "quiz" and len(problems) != 8:
        failures.append(f"{rel}: 퀴즈는 8문제여야 함 ({len(problems)}개)")
    if kind == "test" and len(problems) != 15:
        failures.append(f"{rel}: 테스트는 15문제여야 함 ({len(problems)}개)")
    if is_mock:
        if len(problems) != 25:
            failures.append(f"{rel}: 모의고사는 25문제여야 함 ({len(problems)}개)")
        numbers = sorted(p.get("number", 0) for p in problems)
        if numbers != list(range(1, 26)):
            failures.append(f"{rel}: number가 1~25를 한 번씩 덮지 않음")
        for p in problems:
            n = p.get("number", 0)
            if p.get("band") != band_for_number(n):
                failures.append(f"{p.get('id')}: {n}번인데 band가 {p.get('band')} (기대 {band_for_number(n)})")
    if kind == "problems":
        per_lesson = {}
        for p in problems:
            per_lesson.setdefault(p.get("lesson"), []).append(p.get("band"))
        for lesson in (known_lessons or []):
            bands = per_lesson.get(lesson)
            if not bands:
                failures.append(f"{rel}: 레슨 {lesson}의 연습문제 없음")
                continue
            c = Counter(bands)
            if len(bands) < 10:
                failures.append(f"{rel}: 레슨 {lesson} 연습문제 {len(bands)}개 (최소 10)")
            if c["1-10"] < 3 or c["21-25"] < 3 or c["11-15"] + c["16-20"] < 4:
                failures.append(f"{rel}: 레슨 {lesson} 난이도 분포 {dict(c)} (1-10 ≥3, 11-20 ≥4, 21-25 ≥3)")
    for p in problems:
        total += 1
        pid = p.get("id", "?")
        if pid in seen_ids:
            failures.append(f"{pid}: id 중복")
        seen_ids.add(pid)
        if p.get("band") not in BANDS:
            fail(pid, f"band {p.get('band')!r} 잘못됨")
        if known_lessons is not None and p.get("lesson") not in known_lessons:
            fail(pid, f"lesson {p.get('lesson')!r}가 lessons.md에 없음")
        for key in ("question", "questionKo", "solution"):
            if not p.get(key):
                fail(pid, f"{key} 없음")
        if not p.get("fields"):
            fail(pid, "fields 없음")
        for f_ in p.get("fields", []):
            if f_ not in ("counting", "probability", "numberTheory", "algebra", "geometry", "statistics", "logic"):
                fail(pid, f"알 수 없는 분야 {f_!r}")
        if p.get("choicesKo") is not None and len(p["choicesKo"]) != 5:
            fail(pid, "choicesKo가 5개가 아님")
        if p.get("figure") and not p["figure"].lstrip().startswith("<svg"):
            fail(pid, "figure는 <svg로 시작해야 함")
        elif p.get("figure"):
            for msg in svg_bounds_issues(p["figure"]):
                fail(pid, f"figure {msg}")
        choices = p.get("choices", [])
        letters = "ABCDE"
        if len(choices) != 5:
            fail(pid, f"선택지 {len(choices)}개")
            continue
        if len(set(c.strip() for c in choices)) != 5:
            fail(pid, "선택지 중복")
        if p.get("answer") not in letters:
            fail(pid, f"정답 문자 {p.get('answer')!r}")
            continue
        if not 1 <= len(p.get("hints", [])) <= 3:
            fail(pid, f"힌트 {len(p.get('hints', []))}개")
        if not p.get("solution"):
            fail(pid, "해설 없음")
        if "geometry" in p.get("fields", []) and not p.get("figure"):
            fail(pid, "기하 문제에 그림 없음")
        v = p.get("verify")
        if not v or not v.get("answer"):
            fail(pid, "verify.answer 없음")
            continue
        try:
            ans = evaluate(v["answer"])
        except Exception as e:
            fail(pid, f"verify.answer 평가 실패: {e}")
            continue
        if v.get("choices"):
            if len(v["choices"]) != 5:
                fail(pid, "verify.choices가 5개가 아님")
                continue
            try:
                values = [evaluate(c) for c in v["choices"]]
            except Exception as e:
                fail(pid, f"verify.choices 평가 실패: {e}")
                continue
        else:
            values = [parse_choice(c) for c in choices]
            if any(x is None for x in values):
                bad = [c for c, x in zip(choices, values) if x is None]
                fail(pid, f"숫자로 읽을 수 없는 선택지 {bad} → verify.choices 필요")
                continue
        matches = [i for i, x in enumerate(values) if same(x, ans)]
        if len(matches) != 1:
            fail(pid, f"계산값 {ans} 와 일치하는 선택지가 {len(matches)}개 (값 {values})")
        elif letters[matches[0]] != p["answer"]:
            fail(pid, f"계산값 {ans} 는 선택지 {letters[matches[0]]} 인데 정답이 {p['answer']} 로 표시됨")
        else:
            verified += 1
        # Distinct values, not only distinct strings.
        for i, j in itertools.combinations(range(5), 2):
            if same(values[i], values[j]):
                fail(pid, f"선택지 {letters[i]}와 {letters[j]} 값이 같음 ({values[i]})")
        methods = v.get("methods") or []
        if "geometry" in p.get("fields", []) and len(methods) < 1:
            fail(pid, "기하 문제는 verify.answer(방법 1) 외에 verify.methods에 다른 접근(방법 2)이 필요")
        for k, m in enumerate(methods):
            try:
                got = evaluate(m)
            except Exception as e:
                fail(pid, f"methods[{k}] 평가 실패: {e}")
                continue
            if not same(got, ans):
                fail(pid, f"methods[{k}] = {got} ≠ answer {ans}")
            elif VERBOSE or "geometry" in p.get("fields", []):
                geometry_logged += 1
                print(f"  {pid} method {k + 1}: {m.strip().splitlines()[0][:70]} → {got}")
        if VERBOSE:
            print(f"  {pid}: answer {p['answer']} = {ans}  ok")

# Lesson figures (unitN/figures/*.svg) get the same clipping check.
lesson_figures = 0
for path in sorted(glob.glob(os.path.join(CONTENT, "unit*", "figures", "*.svg"))):
    if MOCK_ONLY or (UNIT_FILTER and f"unit{UNIT_FILTER}{os.sep}" not in path):
        continue
    lesson_figures += 1
    for msg in svg_bounds_issues(open(path, encoding="utf-8").read()):
        failures.append(f"{os.path.relpath(path, ROOT)}: {msg}")

print(f"{total} problems, {verified} answers verified, {lesson_figures} lesson figures checked, {len(failures)} failures")
for f in failures:
    print("FAIL", f)
sys.exit(1 if failures or total == 0 else 0)
