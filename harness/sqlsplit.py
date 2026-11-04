"""Split a SQL script into statements without a server round-trip.

Handles '...', "...", `...` (with backslash and doubled-quote escapes),
-- / # line comments and /* */ block comments. There is no DELIMITER support:
problem files must not define stored programs.
"""
from __future__ import annotations


def _scan(sql: str):
    """Yield (kind, text) chunks: kind is 'code', 'comment', 'string' or 'semi'."""
    i, n = 0, len(sql)
    buf_start = 0

    def flush(end):
        if end > buf_start:
            yield ("code", sql[buf_start:end])

    while i < n:
        ch = sql[i]
        nxt = sql[i + 1] if i + 1 < n else ""
        if ch in "'\"`":
            yield from flush(i)
            j = i + 1
            while j < n:
                if sql[j] == "\\" and ch != "`":
                    j += 2
                    continue
                if sql[j] == ch:
                    if j + 1 < n and sql[j + 1] == ch:  # doubled quote escape
                        j += 2
                        continue
                    break
                j += 1
            yield ("string", sql[i : j + 1])
            i = buf_start = j + 1
        elif (ch == "-" and nxt == "-" and (i + 2 >= n or sql[i + 2] in " \t\r\n")) or ch == "#":
            yield from flush(i)
            j = sql.find("\n", i)
            j = n if j == -1 else j
            yield ("comment", sql[i:j])
            i = buf_start = j
        elif ch == "/" and nxt == "*":
            yield from flush(i)
            j = sql.find("*/", i + 2)
            j = n if j == -1 else j + 2
            yield ("comment", sql[i:j])
            i = buf_start = j
        elif ch == ";":
            yield from flush(i)
            yield ("semi", ";")
            i = buf_start = i + 1
        else:
            i += 1
    yield from flush(n)


def split_statements(sql: str) -> list[str]:
    """Return the statements in `sql`, each without its trailing semicolon.

    Statements that contain only comments/whitespace are dropped. Comments
    inside a statement are kept (the server ignores them).
    """
    statements: list[str] = []
    current: list[str] = []
    has_code = False
    for kind, text in _scan(sql):
        if kind == "semi":
            if has_code:
                statements.append("".join(current).strip())
            current, has_code = [], False
            continue
        current.append(text)
        if kind == "string" or (kind == "code" and text.strip()):
            has_code = True
    if has_code:
        statements.append("".join(current).strip())
    return statements


def strip_comments(sql: str) -> str:
    """Return `sql` with all comments removed (strings untouched)."""
    return "".join(text for kind, text in _scan(sql) if kind != "comment")


def is_blank(sql: str) -> bool:
    """True when the script holds no executable SQL (only comments/whitespace)."""
    return not split_statements(sql)
