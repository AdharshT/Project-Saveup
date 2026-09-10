"""One-off script: copy data from the local SQLite budget.db into MySQL.

Run once, after the MySQL database and tables already exist (i.e. after the
app has been started at least once against SAVEUP_DATABASE_URL so that
run_migrations() has created the schema).

Usage:
    cd backend
    source venv/bin/activate
    export SAVEUP_DATABASE_URL="mysql+pymysql://saveup_user:PASSWORD@localhost/saveup"
    python3 migrate_to_mysql.py
"""
import os
import sys

from sqlalchemy import create_engine, select

from app import models

SQLITE_URL = "sqlite:///./budget.db"
MYSQL_URL = os.environ.get("SAVEUP_DATABASE_URL")

if not MYSQL_URL or not MYSQL_URL.startswith("mysql"):
    sys.exit(
        "Set SAVEUP_DATABASE_URL to the target MySQL connection string before running this."
    )

# Parents before children, so foreign keys resolve as rows are inserted.
TABLE_ORDER = [
    "users",
    "banks",
    "accounts",
    "subscriptions",
    "incomes",
    "transactions",
    "basket_checks",
    "basket_check_items",
]

# user id 27 ('Adharsh', adh03@gmail.com) collides with id 1 ('adharsh',
# ad@gmail.com) under MySQL's case-insensitive default collation on
# username. Treated as stale test data and skipped, along with everything
# that references it.
SKIP_USER_IDS = {27}

sqlite_engine = create_engine(SQLITE_URL)
mysql_engine = create_engine(MYSQL_URL)

skipped_basket_check_ids = set()

with sqlite_engine.connect() as sconn, mysql_engine.begin() as mconn:
    mconn.exec_driver_sql("SET FOREIGN_KEY_CHECKS=0")
    for name in TABLE_ORDER:
        table = models.Base.metadata.tables[name]
        rows = [dict(row._mapping) for row in sconn.execute(select(table))]

        if name == "users":
            rows = [r for r in rows if r["id"] not in SKIP_USER_IDS]
        elif "user_id" in table.columns:
            kept = [r for r in rows if r["user_id"] not in SKIP_USER_IDS]
            if name == "basket_checks":
                skipped_basket_check_ids.update(
                    r["id"] for r in rows if r["user_id"] in SKIP_USER_IDS
                )
            rows = kept
        elif name == "basket_check_items":
            rows = [r for r in rows if r["basket_check_id"] not in skipped_basket_check_ids]

        mconn.execute(table.delete())
        if rows:
            mconn.execute(table.insert(), rows)
        print(f"{name}: copied {len(rows)} rows")
    mconn.exec_driver_sql("SET FOREIGN_KEY_CHECKS=1")

print("Done.")
