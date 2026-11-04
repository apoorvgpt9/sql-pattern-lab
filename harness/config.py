"""Connection settings and repository paths."""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PROBLEMS_DIR = REPO_ROOT / "problems"
PROBLEMS_YAML = REPO_ROOT / "problems.yaml"
BENCH_RESULTS_DIR = REPO_ROOT / "bench" / "results"

# MySQL 8.0's default sql_mode, set explicitly so results do not depend on how
# the local server was configured.
SQL_MODE = (
    "ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,"
    "ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"
)


@dataclass(frozen=True)
class MySQLConfig:
    host: str
    port: int
    user: str
    password: str

    @classmethod
    def from_env(cls) -> "MySQLConfig":
        return cls(
            host=os.environ.get("MYSQL_HOST", "127.0.0.1"),
            port=int(os.environ.get("MYSQL_PORT", "3306")),
            user=os.environ.get("MYSQL_USER", "root"),
            password=os.environ.get("MYSQL_PASSWORD", "root"),
        )

    def describe(self) -> str:
        return f"{self.user}@{self.host}:{self.port}"
