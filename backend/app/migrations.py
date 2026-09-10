from datetime import date

from dateutil.relativedelta import relativedelta
from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine

from . import models

_TABLES_NEEDING_ACCOUNT = ["subscriptions", "incomes", "transactions"]

_REGRESS_DELTA = {
    "weekly": relativedelta(weeks=1),
    "monthly": relativedelta(months=1),
    "quarterly": relativedelta(months=3),
    "yearly": relativedelta(years=1),
}


def _column_exists(conn, table: str, column: str) -> bool:
    return any(c["name"] == column for c in inspect(conn).get_columns(table))


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


def _index_exists(conn, table: str, index_name: str) -> bool:
    return any(idx["name"] == index_name for idx in inspect(conn).get_indexes(table))


def _migrate_users_table(conn):
    """Rename users.name -> username, de-duplicate, add a unique index, and
    add back a separate display `name` column (backfilled from username)."""
    if _column_exists(conn, "users", "name") and not _column_exists(conn, "users", "username"):
        conn.execute(text("ALTER TABLE users RENAME COLUMN name TO username"))

    if not _index_exists(conn, "users", "ix_users_username"):
        dupes = conn.execute(
            text("SELECT username FROM users GROUP BY username HAVING COUNT(*) > 1")
        ).fetchall()
        for (username,) in dupes:
            rows = conn.execute(
                text("SELECT id FROM users WHERE username = :u ORDER BY id"),
                {"u": username},
            ).fetchall()
            for i, (user_id,) in enumerate(rows[1:], start=2):
                conn.execute(
                    text("UPDATE users SET username = :u WHERE id = :id"),
                    {"u": f"{username}{i}", "id": user_id},
                )

        conn.execute(text("CREATE UNIQUE INDEX ix_users_username ON users(username)"))

    if not _column_exists(conn, "users", "name"):
        conn.execute(text("ALTER TABLE users ADD COLUMN name TEXT"))
    conn.execute(text("UPDATE users SET name = username WHERE name IS NULL"))


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


def _migrate_subscriptions_table(conn):
    """Add last_payment_date, backfilled by stepping back one cycle from
    next_billing_date for any pre-existing subscription rows."""
    if not _column_exists(conn, "subscriptions", "last_payment_date"):
        conn.execute(text("ALTER TABLE subscriptions ADD COLUMN last_payment_date DATE"))

    rows = conn.execute(
        text(
            "SELECT id, next_billing_date, billing_cycle FROM subscriptions "
            "WHERE last_payment_date IS NULL"
        )
    ).fetchall()
    for sub_id, next_billing_date, billing_cycle in rows:
        next_date = date.fromisoformat(next_billing_date)
        delta = _REGRESS_DELTA.get(billing_cycle, relativedelta(months=1))
        last_payment_date = next_date - delta
        conn.execute(
            text("UPDATE subscriptions SET last_payment_date = :lpd WHERE id = :id"),
            {"lpd": last_payment_date.isoformat(), "id": sub_id},
        )


def run_migrations(engine: Engine):
    """Create any new tables, then backfill account_id on pre-existing rows.

    SQLAlchemy's create_all only creates missing tables, so the banks
    table appears automatically; columns added to already-existing tables
    need a manual ALTER TABLE plus a one-time backfill.
    """
    models.Base.metadata.create_all(bind=engine)

    with engine.begin() as conn:
        _migrate_users_table(conn)
        _migrate_accounts_table(conn)
        _migrate_subscriptions_table(conn)

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
