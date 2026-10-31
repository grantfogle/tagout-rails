#!/usr/bin/env python3
"""Parse a CPW "Post Draw Recap" PDF text dump into the db/seeds/co_*_stats.json format.

Usage:
  pdftotext -layout report.pdf report.txt
  script/parse_draw_report.py report.txt Bear out.json [weighted_out.json]

Weighted-draw reports (extra Weighted Points column) are summed per preference\nlevel, since hunt_stats has a single points dimension.\n\nAdult rows only (matching the existing elk/deer/pronghorn seeds); landowner (LPP)
and youth columns are ignored. Prints a validation report and exits non-zero if
any block fails a check.
"""
import json
import re
import sys
from collections import Counter

METHODS = {"A": "Archery", "M": "Muzzleloader", "R": "Rifle"}
CODE = r"[A-Z]{2}[A-Z0-9]{3}[A-Z0-9]{2}[A-Z]"
# One code, or several sharing a quota and applicant pool (e.g. moose "MF006O1A MF006O1M MF006O1R").
HUNT_CODE_LINE = re.compile(r"^\s{20,}(%s(?:\s+%s)*)\s*$" % (CODE, CODE))
NUM = r"(?:\d+|-)"
TOKEN = re.compile(r"^(?:\d+|-)$")
TOTAL = re.compile(
    r"^\s*Total Choice (\d)\s+((?:%s\s+){5}%s)\s+Total Choice (\d)\s+((?:%s\s+){5}%s)\s*$" % (NUM, NUM, NUM, NUM)
)


def n(tok):
    return 0 if tok == "-" else int(tok)


def cols(s):
    return [n(t) for t in s.split()]


def parse_row(line, w=7):
    """Return (pref, left_cols, right_cols, weighted) or None (weighted is None for standard layouts).

    Each side of a row is `w` tokens: pref [, weighted] + 6 count columns (w is 7,
    or 8 for weighted-draw species). When a row sits mid-block the PDF also prints
    the choice number inline: at the start and/or before the right-hand table. Try
    each way of dropping those and keep the one where both sides' point values agree.
    """
    toks = line.split()
    if len(toks) not in (2 * w, 2 * w + 1, 2 * w + 2) or not all(TOKEN.match(t) for t in toks):
        return None
    drops = {2 * w: [()], 2 * w + 1: [(0,), (w,)], 2 * w + 2: [(0, w + 1)]}[len(toks)]
    k = w - 6  # number of point columns per side
    found = []
    for drop in drops:
        t = [x for i, x in enumerate(toks) if i not in drop]
        left, right = t[:w], t[w:]
        if "-" not in left[:k] and left[:k] == right[:k]:
            weighted = int(left[1]) if k == 2 else None
            found.append((int(left[0]), [n(x) for x in left[k:]], [n(x) for x in right[k:]], weighted))
    return found[0] if len(found) == 1 else (("ambiguous", line) if found else None)


def identity(codes):
    """(hunt_code, method) for a block. Shared-pool blocks and unmapped method letters
    (moose 'X') are stored with no method; shared pools use the code minus its letter."""
    if len(codes) > 1:
        stems = {c[:-1] for c in codes}
        return (stems.pop(), None) if len(stems) == 1 else (None, None)
    code = codes[0]
    return code, METHODS.get(code[-1])


def split_blocks(lines):
    blocks, code, buf = [], None, []
    for line in lines:
        m = HUNT_CODE_LINE.match(line)
        if m:
            if code:
                blocks.append((code, buf))
            code, buf = tuple(m.group(1).split()), []
        elif code:
            buf.append(line)
    if code:
        blocks.append((code, buf))
    return blocks


def parse_block(code, lines, w=7):
    prefs, totals, errors = [], {}, []
    for line in lines:
        row = parse_row(line, w)
        if row:
            if row[0] == "ambiguous":
                errors.append("ambiguous row: " + row[1].strip())
            else:
                prefs.append(row)
            continue
        m = TOTAL.match(line)
        if m:
            if m.group(1) != m.group(3):
                errors.append("total choice mismatch")
                continue
            totals[int(m.group(1))] = (cols(m.group(2)), cols(m.group(4)))
    # Weighted-draw species print several rows per preference level; sum them.
    raw = [(v, w, l, r) for v, l, r, w in prefs]
    merged = {}
    for value, left, right, _ in prefs:
        m = merged.setdefault(value, ([0] * 6, [0] * 6))
        m[0][:] = [a + b for a, b in zip(m[0], left)]
        m[1][:] = [a + b for a, b in zip(m[1], right)]
    prefs = [(v, l, r) for v, (l, r) in sorted(merged.items(), reverse=True)]
    return prefs, totals, errors, raw


def main(txt_path, species, out_path, weighted_path=None):
    with open(txt_path, encoding="utf-8") as f:
        text = f.read()
    blocks = split_blocks(text.splitlines())
    width = 8 if "Weighted" in text else 7  # weighted draw adds a weighted-points column

    rows, weighted_rows, problems, warnings, seen, skipped, nomethod = [], [], [], [], set(), [], []
    for codes, lines in blocks:
        code, method = identity(codes)
        if code is None:
            problems.append("%s: shared block with mixed stems" % " ".join(codes))
            continue
        if code in seen:
            problems.append("%s: duplicate block" % code)
            continue
        seen.add(code)
        if code.endswith("99999P"):  # "preference point only" pseudo-hunt, not a draw
            skipped.append(code)
            continue
        prefs, totals, errors, raw = parse_block(code, lines, width)
        problems += ["%s: %s" % (code, e) for e in errors]
        if not totals:
            problems.append("%s: no Total Choice rows" % code)
            continue
        if method is None:
            nomethod.append(code)

        # Preference rows only appear under Choice 1, so they must sum to its total.
        for idx, label in ((0, "res"), (1, "nonres")):
            for side, name in ((1, "applicants"), (2, "success")):
                got = sum(p[side][idx] for p in prefs)
                want = totals.get(1, ([0] * 6, [0] * 6))[side - 1][idx]
                if abs(got - want) == 1:
                    # A few CPW blocks print rows that sum to one less than their own
                    # Total Choice 1 (confirmed against the PDF image); not a parse miss.
                    warnings.append("%s: pref %s %s sum %d vs Total Choice 1 %d (source off by 1)" % (code, label, name, got, want))
                elif got != want:
                    problems.append("%s: pref %s %s sum %d != Total Choice 1 %d" % (code, label, name, got, want))

        for resident, idx in ((True, 0), (False, 1)):
            for pref, weighted, left, right in raw:
                if weighted is not None:
                    weighted_rows.append({
                        "hunt_code": code, "resident": resident, "adult": True,
                        "preference_points": pref, "weighted_points": weighted,
                        "applicants": left[idx], "success": right[idx],
                    })

        base = {
            "hunt_code": code, "state": "CO", "species": species, "sex": code[1],
            "unit": code[2:5], "season": code[5:7], "method": method,
        }
        for resident, idx in ((True, 0), (False, 1)):
            for value, left, right in prefs:
                rows.append(dict(base, resident=resident, adult=True, type="pref",
                                 value=value, applicants=left[idx], success=right[idx]))
            for choice in sorted(totals):
                app, suc = totals[choice]
                rows.append(dict(base, resident=resident, adult=True, type="total_choice",
                                 value=choice, applicants=app[idx], success=suc[idx]))

    with open(out_path, "w") as f:
        json.dump(rows, f, indent=2)
    if weighted_path and weighted_rows:
        with open(weighted_path, "w") as f:
            json.dump(weighted_rows, f, indent=2)

    print("layout:            %s" % ("weighted (summed per preference level)" if width == 8 else "standard"))
    print("hunt codes parsed: %d (skipped pseudo-codes: %s)" % (len(seen) - len(skipped), skipped))
    if weighted_path:
        print("weighted rows:     %d" % len(weighted_rows))
    print("rows written:      %d  %s" % (len(rows), dict(Counter(r["type"] for r in rows))))
    print("seasons:           %s" % sorted({r["season"] for r in rows}))
    print("sexes:             %s" % sorted({r["sex"] for r in rows}))
    print("methods:           %s" % sorted({str(r["method"]) for r in rows}))
    print("no method:         %d codes %s" % (len(nomethod), nomethod[:6]))
    print("warnings:          %d" % len(warnings))
    for w in warnings[:10]:
        print("  ~ " + w)
    print("problems:          %d" % len(problems))
    for p in problems[:40]:
        print("  - " + p)
    return 1 if problems else 0


if __name__ == "__main__":
    if len(sys.argv) not in (4, 5):
        sys.exit(__doc__)
    sys.exit(main(*sys.argv[1:]))
