"""MySQL helpers: connections, throwaway databases, script execution, data loading."""
from __future__ import annotations

import itertools
import os
import time
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator

import pymysql
import pymysql.cursors

from .config import SQL_MODE, MySQLConfig
from .sqlsplit import split_statements

_counter = itertools.count(1)


class SqlError(Exception):
    """A statement failed; carries the file and statement for a readable report."""

    def __init__(self, source: str, statement: str, error: Exception):
        self.source, self.statement, self.error = source, statement, error
        short = statement if len(statement) < 600 else statement[:600] + " ..."
        super().__init__(f"{source}: {error}\n--- failing statement ---\n{short}")


def connect(cfg: MySQLConfig | None = None, *, local_infile: bool = False,
            database: str | None = None, **kwargs) -> pymysql.connections.Connection:
    cfg = cfg or MySQLConfig.from_env()
    conn = pymysql.connect(
        host=cfg.host, port=cfg.port, user=cfg.user, password=cfg.password,
        database=database, charset="utf8mb4", autocommit=True,
        local_infile=local_infile, **kwargs,
    )
    with conn.cursor() as cur:
        cur.execute("SET SESSION sql_mode = %s", (SQL_MODE,))
        cur.execute("SET SESSION time_zone = '+00:00'")
    return conn


def wait_for_server(timeout_s: float = 120.0, cfg: MySQLConfig | None = None) -> str:
    """Block until the server accepts connections; return its version."""
    cfg = cfg or MySQLConfig.from_env()
    deadline = time.monotonic() + timeout_s
    last: Exception | None = None
    while time.monotonic() < deadline:
        try:
            conn = connect(cfg)
            with conn.cursor() as cur:
                cur.execute("SELECT VERSION()")
                version = cur.fetchone()[0]
            conn.close()
            return version
        except pymysql.err.MySQLError as exc:  # server still starting
            last = exc
            time.sleep(2)
    raise RuntimeError(f"MySQL at {cfg.describe()} not reachable after {timeout_s}s: {last}")


@contextmanager
def fresh_database(prefix: str = "spl_t", *, local_infile: bool = False,
                   cfg: MySQLConfig | None = None) -> Iterator[pymysql.connections.Connection]:
    """Create an empty database, yield a connection using it, drop it afterwards."""
    name = f"{prefix}_{os.getpid()}_{next(_counter)}"
    conn = connect(cfg, local_infile=local_infile)
    try:
        with conn.cursor() as cur:
            cur.execute(f"DROP DATABASE IF EXISTS `{name}`")
            cur.execute(f"CREATE DATABASE `{name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci")
        conn.select_db(name)
        yield conn
    finally:
        try:
            with conn.cursor() as cur:
                cur.execute(f"DROP DATABASE IF EXISTS `{name}`")
        finally:
            conn.close()


@dataclass
class QueryResult:
    columns: list[str]
    rows: list[tuple]


def run_script(conn, sql: str, source: str = "<sql>") -> QueryResult | None:
    """Execute every statement in `sql`; return the last result set produced, if any."""
    result: QueryResult | None = None
    with conn.cursor() as cur:
        for stmt in split_statements(sql):
            try:
                cur.execute(stmt)
            except pymysql.err.MySQLError as exc:
                raise SqlError(source, stmt, exc) from exc
            if cur.description is not None:
                result = QueryResult([d[0] for d in cur.description], list(cur.fetchall()))
    return result


def run_file(conn, path: Path) -> QueryResult | None:
    return run_script(conn, path.read_text(encoding="utf-8"), source=str(path))


def run_solution(conn, path: Path) -> QueryResult:
    result = run_file(conn, path)
    if result is None:
        raise AssertionError(f"{path} produced no result set (its last statement must be a SELECT)")
    return result


def table_columns(conn, table: str) -> list[str]:
    """Insertable columns of `table` in the current database, in ordinal order."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT COLUMN_NAME FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s "
            "AND EXTRA NOT LIKE '%%GENERATED%%' ORDER BY ORDINAL_POSITION",
            (table,),
        )
        cols = [r[0] for r in cur.fetchall()]
    if not cols:
        raise AssertionError(f"gen.py returned rows for table {table!r}, which schema.sql does not create")
    return cols


def table_row_counts(conn) -> dict[str, int]:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT TABLE_NAME FROM information_schema.TABLES "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE'"
        )
        tables = [r[0] for r in cur.fetchall()]
        counts = {}
        for t in tables:
            cur.execute(f"SELECT COUNT(*) FROM `{t}`")
            counts[t] = cur.fetchone()[0]
    return counts


def insert_rows(conn, table: str, rows: Iterable[tuple], batch: int = 2000) -> int:
    """Insert generated rows with multi-row INSERTs; return the row count."""
    cols = table_columns(conn, table)
    col_sql = ", ".join(f"`{c}`" for c in cols)
    sql = f"INSERT INTO `{table}` ({col_sql}) VALUES ({', '.join(['%s'] * len(cols))})"
    total = 0
    chunk: list[tuple] = []
    with conn.cursor() as cur:
        for row in rows:
            if len(row) != len(cols):
                raise AssertionError(
                    f"gen.py row for {table} has {len(row)} values, table has {len(cols)} columns {cols}: {row!r}")
            chunk.append(tuple(row))
            if len(chunk) >= batch:
                cur.executemany(sql, chunk)
                total += len(chunk)
                chunk = []
        if chunk:
            cur.executemany(sql, chunk)
            total += len(chunk)
    return total


def load_generated(conn, data: dict[str, Iterable[tuple]]) -> dict[str, int]:
    return {table: insert_rows(conn, table, rows) for table, rows in data.items()}
