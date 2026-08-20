from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db
from ..dateutils import monthly_equivalent

router = APIRouter(prefix="/affordability", tags=["affordability"])


@router.post("/check", response_model=schemas.AffordabilityResponse)
def check_affordability(payload: schemas.AffordabilityRequest, db: Session = Depends(get_db)):
    today = date.today()

    incomes = db.query(models.Income).filter(models.Income.active.is_(True)).all()
    monthly_income = sum(monthly_equivalent(i.amount, i.frequency) for i in incomes)

    subscriptions = db.query(models.Subscription).filter(models.Subscription.active.is_(True)).all()
    monthly_subscription_cost = sum(
        monthly_equivalent(s.amount, s.billing_cycle) for s in subscriptions
    )

    spending_this_month = (
        db.query(models.Transaction)
        .filter(
            models.Transaction.date >= date(today.year, today.month, 1),
            models.Transaction.date <= today,
        )
        .all()
    )
    spending_total = sum(t.amount for t in spending_this_month)

    discretionary_balance = monthly_income - monthly_subscription_cost - spending_total
    balance_after_purchase = discretionary_balance - payload.price
    can_afford = balance_after_purchase >= 0

    if can_afford:
        message = (
            f"You can afford {payload.item_name}. You'd have "
            f"${balance_after_purchase:,.2f} left in this month's discretionary budget."
        )
    else:
        message = (
            f"Buying {payload.item_name} would put you ${-balance_after_purchase:,.2f} over "
            "your estimated discretionary budget for this month."
        )

    return schemas.AffordabilityResponse(
        item_name=payload.item_name,
        price=payload.price,
        can_afford=can_afford,
        monthly_income=round(monthly_income, 2),
        monthly_subscription_cost=round(monthly_subscription_cost, 2),
        spending_this_month=round(spending_total, 2),
        discretionary_balance=round(discretionary_balance, 2),
        balance_after_purchase=round(balance_after_purchase, 2),
        message=message,
    )
