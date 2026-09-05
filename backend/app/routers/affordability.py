from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import get_current_user
from ..database import get_db
from ..dateutils import effective_income_amount, monthly_equivalent

router = APIRouter(prefix="/affordability", tags=["affordability"])


def _join_names(names: list[str]) -> str:
    if len(names) == 1:
        return names[0]
    if len(names) == 2:
        return f"{names[0]} and {names[1]}"
    return f"{', '.join(names[:-1])}, and {names[-1]}"


def _build_response(basket: models.BasketCheck, items: list[models.BasketCheckItem]):
    return schemas.AffordabilityResponse(
        id=basket.id,
        items=[schemas.BasketItem.model_validate(item) for item in items],
        total_price=basket.total_price,
        can_afford=basket.can_afford,
        monthly_income=basket.monthly_income,
        monthly_subscription_cost=basket.monthly_subscription_cost,
        spending_this_month=basket.spending_this_month,
        discretionary_balance=basket.discretionary_balance,
        balance_after_purchase=basket.balance_after_purchase,
        message=basket.message,
        created_at=basket.created_at,
    )


@router.post("/check", response_model=schemas.AffordabilityResponse, status_code=201)
def check_affordability(
    payload: schemas.AffordabilityRequest,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    if not payload.items:
        raise HTTPException(status_code=400, detail="Add at least one item to your basket.")

    today = date.today()

    incomes = (
        db.query(models.Income)
        .filter(models.Income.user_id == user.id, models.Income.active.is_(True))
        .all()
    )
    monthly_income = sum(
        monthly_equivalent(effective_income_amount(i.amount, i.pay_type, i.hours_per_period), i.frequency)
        for i in incomes
    )

    subscriptions = (
        db.query(models.Subscription)
        .filter(models.Subscription.user_id == user.id, models.Subscription.active.is_(True))
        .all()
    )
    monthly_subscription_cost = sum(
        monthly_equivalent(s.amount, s.billing_cycle) for s in subscriptions
    )

    spending_this_month = (
        db.query(models.Transaction)
        .filter(
            models.Transaction.user_id == user.id,
            models.Transaction.date >= date(today.year, today.month, 1),
            models.Transaction.date <= today,
        )
        .all()
    )
    spending_total = sum(t.amount for t in spending_this_month)

    total_price = sum(item.price for item in payload.items)
    combined_name = _join_names([item.name for item in payload.items])

    discretionary_balance = monthly_income - monthly_subscription_cost - spending_total
    balance_after_purchase = discretionary_balance - total_price
    can_afford = balance_after_purchase >= 0

    if can_afford:
        message = (
            f"You can afford {combined_name}. You'd have "
            f"${balance_after_purchase:,.2f} left in this month's discretionary budget."
        )
    else:
        message = (
            f"Buying {combined_name} would put you ${-balance_after_purchase:,.2f} over "
            "your estimated discretionary budget for this month."
        )

    basket = models.BasketCheck(
        user_id=user.id,
        total_price=round(total_price, 2),
        can_afford=can_afford,
        message=message,
        monthly_income=round(monthly_income, 2),
        monthly_subscription_cost=round(monthly_subscription_cost, 2),
        spending_this_month=round(spending_total, 2),
        discretionary_balance=round(discretionary_balance, 2),
        balance_after_purchase=round(balance_after_purchase, 2),
    )
    db.add(basket)
    db.flush()

    items = [
        models.BasketCheckItem(basket_check_id=basket.id, name=item.name, price=item.price)
        for item in payload.items
    ]
    db.add_all(items)
    db.commit()
    db.refresh(basket)
    for item in items:
        db.refresh(item)

    return _build_response(basket, items)


@router.get("/history", response_model=list[schemas.AffordabilityResponse])
def list_history(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    baskets = (
        db.query(models.BasketCheck)
        .filter(models.BasketCheck.user_id == user.id)
        .order_by(models.BasketCheck.created_at.desc())
        .all()
    )
    result = []
    for basket in baskets:
        items = (
            db.query(models.BasketCheckItem)
            .filter(models.BasketCheckItem.basket_check_id == basket.id)
            .all()
        )
        result.append(_build_response(basket, items))
    return result


@router.delete("/history/{basket_id}", status_code=204)
def delete_history_entry(
    basket_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    basket = db.get(models.BasketCheck, basket_id)
    if not basket or basket.user_id != user.id:
        raise HTTPException(status_code=404, detail="Basket check not found")

    db.query(models.BasketCheckItem).filter(
        models.BasketCheckItem.basket_check_id == basket_id
    ).delete()
    db.delete(basket)
    db.commit()
