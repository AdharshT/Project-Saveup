from sqlalchemy import text
from sqlalchemy.engine import Engine

from . import models

_TABLES_NEEDING_ACCOUNT = ["subscriptions", "incomes", "transactions"]


def _column_exists(conn, table: str, column: str) -> bool:
    rows = conn.execute(text(f"PRAGMA table_info({table})")).fetchall()
    return any(row[1] == column for row in rows)


def _get_or_create_unknown_bank(conn, user_id: int) -> int:
    existing_bank = conn.execute(
        text("SELECT id FROM banks WHERE user_id = :uid ORDER BY id LIMIT 1"),
        {"uid": user_id},
    ).fetchone()
    if existing_bank:
        return existing_bank[0]

    result = conn.execute(
        text("INSERT INTO banks (user_id, name) VALUES (:uid, 'Unknown Bank')"),
        {"uid": user_id},
    )
    return result.lastrowid


def _migrate_accounts_table(conn):
    """Rename accounts.name -> nickname and add the bank_id/type/last4 columns."""
    if _column_exists(conn, "accounts", "name") and not _column_exists(
        conn, "accounts", "nickname"
    ):
        conn.execute(text("ALTER TABLE accounts RENAME COLUMN name TO nickname"))

    for column, ddl_type in [("bank_id", "INTEGER"), ("type", "TEXT"), ("last4", "TEXT")]:
        if not _column_exists(conn, "accounts", column):
            conn.execute(text(f"ALTER TABLE accounts ADD COLUMN {column} {ddl_type}"))

    user_ids = conn.execute(
        text("SELECT DISTINCT user_id FROM accounts WHERE bank_id IS NULL")
    ).fetchall()
    for (user_id,) in user_ids:
        bank_id = _get_or_create_unknown_bank(conn, user_id)
        conn.execute(
            text("UPDATE accounts SET bank_id = :bid WHERE user_id = :uid AND bank_id IS NULL"),
            {"bid": bank_id, "uid": user_id},
        )


def run_migrations(engine: Engine):
    """Create any new tables, then backfill account_id on pre-existing rows.

    SQLAlchemy's create_all only creates missing tables, so the banks
    table appears automatically; columns added to already-existing tables
    need a manual ALTER TABLE plus a one-time backfill.
    """
    models.Base.metadata.create_all(bind=engine)

    with engine.begin() as conn:
        _migrate_accounts_table(conn)

        for table in _TABLES_NEEDING_ACCOUNT:
            if not _column_exists(conn, table, "account_id"):
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN account_id INTEGER"))

        user_ids_needing_backfill = set()
        for table in _TABLES_NEEDING_ACCOUNT:
            rows = conn.execute(
                text(f"SELECT DISTINCT user_id FROM {table} WHERE account_id IS NULL")
            ).fetchall()
            user_ids_needing_backfill.update(row[0] for row in rows)

        for user_id in user_ids_needing_backfill:
            existing = conn.execute(
                text("SELECT id FROM accounts WHERE user_id = :uid ORDER BY id LIMIT 1"),
                {"uid": user_id},
            ).fetchone()
            if existing:
                account_id = existing[0]
            else:
                bank_id = _get_or_create_unknown_bank(conn, user_id)
                result = conn.execute(
                    text(
                        "INSERT INTO accounts (user_id, bank_id, nickname, balance) "
                        "VALUES (:uid, :bid, 'Primary', 0.0)"
                    ),
                    {"uid": user_id, "bid": bank_id},
                )
                account_id = result.lastrowid

            for table in _TABLES_NEEDING_ACCOUNT:
                conn.execute(
                    text(
                        f"UPDATE {table} SET account_id = :aid "
                        "WHERE user_id = :uid AND account_id IS NULL"
                    ),
                    {"aid": account_id, "uid": user_id},
                )
