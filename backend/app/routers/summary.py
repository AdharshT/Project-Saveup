from collections import defaultdict
from datetime import date

from dateutil.relativedelta import relativedelta
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import get_current_user
from ..database import get_db

router = APIRouter(prefix="/summary", tags=["summary"])


@router.get("/monthly", response_model=schemas.MonthlyComparison)
def monthly_comparison(
    months: int = Query(default=6, ge=1, le=24),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    today = date.today()
    start_month = date(today.year, today.month, 1) - relativedelta(months=months - 1)

    transactions = (
        db.query(models.Transaction)
        .filter(models.Transaction.user_id == user.id, models.Transaction.date >= start_month)
        .all()
    )

    totals: dict[str, float] = defaultdict(float)
    by_category: dict[str, dict[str, float]] = defaultdict(lambda: defaultdict(float))

    for txn in transactions:
        key = f"{txn.date.year:04d}-{txn.date.month:02d}"
        totals[key] += txn.amount
        category = txn.category or "Uncategorized"
        by_category[key][category] += txn.amount

    result = []
    cursor = start_month
    for _ in range(months):
        key = f"{cursor.year:04d}-{cursor.month:02d}"
        result.append(
            schemas.MonthlyTotal(
                month=key,
                total=round(totals.get(key, 0.0), 2),
                by_category={k: round(v, 2) for k, v in by_category.get(key, {}).items()},
            )
        )
        cursor = cursor + relativedelta(months=1)

    return schemas.MonthlyComparison(months=result)
