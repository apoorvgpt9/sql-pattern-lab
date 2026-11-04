"""Normalise and compare query results with hand-written expected CSVs.

Rules
- Column names: compared case-insensitively, in order.
- Literal NULL in the CSV (quoted or not) is SQL NULL; an empty field is ''.
- Numbers (on either side, including numeric-looking strings) are rounded to
  5 decimal places (half-even) before comparison, so 2, 2.0 and 2.000001 match.
- Dates/datetimes/times are compared in MySQL's text form ('YYYY-MM-DD HH:MM:SS').
- Rows are compared as a multiset unless the problem's ordering is exact.
"""
from __future__ import annotations

import csv
import datetime as dt
import re
from collections import Counter
from decimal import ROUND_HALF_EVEN, Decimal, InvalidOperation
from pathlib import Path

PLACES = Decimal("0.00001")
_NUMERIC = re.compile(r"^[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?$")
_ISO_T = re.compile(r"^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}(:\d{2}(\.\d+)?)?)$")

Row = tuple


def _num(d: Decimal) -> str:
    q = d.quantize(PLACES, rounding=ROUND_HALF_EVEN)
    if q.is_zero():
        q = abs(q)  # -0.00000 -> 0.00000
    return f"N:{q}"


def _timedelta(td: dt.timedelta) -> str:
    total = int(td.total_seconds())
    sign = "-" if total < 0 else ""
    total = abs(total)
    h, rem = divmod(total, 3600)
    m, s = divmod(rem, 60)
    return f"{sign}{h:02d}:{m:02d}:{s:02d}"


def normalize(value):
    """Map a DB value or CSV cell to a canonical comparable form (str or None)."""
    if value is None:
        return None
    if isinstance(value, bool):
        return _num(Decimal(int(value)))
    if isinstance(value, int):
        return _num(Decimal(value))
    if isinstance(value, float):
        return _num(Decimal(repr(value)))
    if isinstance(value, Decimal):
        return _num(value)
    if isinstance(value, dt.datetime):
        text = value.strftime("%Y-%m-%d %H:%M:%S")
        if value.microsecond:
            text += f".{value.microsecond:06d}".rstrip("0")
        return f"S:{text}"
    if isinstance(value, dt.date):
        return f"S:{value.isoformat()}"
    if isinstance(value, dt.timedelta):
        return f"S:{_timedelta(value)}"
    if isinstance(value, (bytes, bytearray)):
        value = value.decode("utf-8", errors="replace")
    text = str(value)
    if _NUMERIC.match(text.strip()):
        try:
            return _num(Decimal(text.strip()))
        except InvalidOperation:
            pass
    m = _ISO_T.match(text)
    if m:
        text = f"{m.group(1)} {m.group(2)}"
    return f"S:{text}"


def normalize_row(row) -> Row:
    return tuple(normalize(v) for v in row)


def display(value) -> str:
    """Human-readable form of a normalised value."""
    if value is None:
        return "NULL"
    kind, text = value[0], value[2:]
    if kind == "N":
        text = text.rstrip("0").rstrip(".") if "." in text else text
    return text


def display_row(row: Row) -> str:
    return "(" + ", ".join(display(v) for v in row) + ")"


def _sort_key(row: Row):
    return tuple("" if v is None else "\x01" + v for v in row)


def read_expected(path: Path) -> tuple[list[str], list[Row]]:
    """Read an expected CSV: header row = output columns, literal NULL = SQL NULL."""
    with path.open(newline="", encoding="utf-8") as fh:
        reader = csv.reader(fh)
        try:
            header = next(reader)
        except StopIteration:
            raise AssertionError(f"{path} is empty; it needs at least a header row") from None
        header = [h.strip() for h in header]
        rows = []
        for lineno, raw in enumerate(reader, start=2):
            if not raw:
                continue  # blank line
            if len(raw) != len(header):
                raise AssertionError(f"{path}:{lineno} has {len(raw)} fields, header has {len(header)}")
            rows.append(tuple(None if cell.strip() == "NULL" else cell for cell in raw))
    return header, rows


def columns_match(actual: list[str], expected: list[str]) -> bool:
    return [c.lower() for c in actual] == [c.lower() for c in expected]


def multiset_diff(a: list[Row], b: list[Row]) -> tuple[list[Row], list[Row]]:
    """Rows in a but not b, rows in b but not a (with multiplicity)."""
    ca, cb = Counter(a), Counter(b)
    only_a = sorted((ca - cb).elements(), key=_sort_key)
    only_b = sorted((cb - ca).elements(), key=_sort_key)
    return only_a, only_b


def _fmt_rows(rows: list[Row], limit: int) -> str:
    shown = "\n".join("    " + display_row(r) for r in rows[:limit])
    more = f"\n    ... and {len(rows) - limit} more" if len(rows) > limit else ""
    return shown + more


def compare_results(actual_cols: list[str], actual_rows: list, expected_cols: list[str],
                    expected_rows: list, *, exact_order: bool, limit: int = 15) -> str | None:
    """Return None when equal, otherwise a readable explanation of the difference."""
    if not columns_match(actual_cols, expected_cols):
        return (f"column names differ (case-insensitive, in order):\n"
                f"  expected: {expected_cols}\n  actual:   {actual_cols}")
    act = [normalize_row(r) for r in actual_rows]
    exp = [normalize_row(r) for r in expected_rows]
    missing, extra = multiset_diff(exp, act)
    if missing or extra:
        parts = [f"rows differ: expected {len(exp)} rows, got {len(act)}"]
        if missing:
            parts.append(f"  missing (expected but not returned):\n{_fmt_rows(missing, limit)}")
        if extra:
            parts.append(f"  unexpected (returned but not expected):\n{_fmt_rows(extra, limit)}")
        return "\n".join(parts)
    if exact_order and act != exp:
        first = next(i for i, (x, y) in enumerate(zip(act, exp)) if x != y)
        return (f"same rows, wrong order (ordering is exact for this problem); first difference at row {first + 1}:\n"
                f"  expected order:\n{_fmt_rows(exp, limit)}\n  actual order:\n{_fmt_rows(act, limit)}")
    return None


def result_digest(rows: list) -> str:
    """Order-insensitive fingerprint of a result, for cross-checking bench runs."""
    import hashlib

    h = hashlib.sha1()
    for r in sorted((normalize_row(r) for r in rows), key=_sort_key):
        h.update(repr(r).encode())
        h.update(b"\n")
    return h.hexdigest()
