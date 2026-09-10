from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import get_current_user
from ..database import get_db
from ..dateutils import advance

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])


def _ensure_account_owned(account_id: int, db: Session, user: models.User):
    account = db.get(models.Account, account_id)
    if not account or account.user_id != user.id:
        raise HTTPException(status_code=400, detail="Account not found")


@router.get("", response_model=list[schemas.Subscription])
def list_subscriptions(
    db: Session = Depends(get_db), user: models.User = Depends(get_current_user)
):
    return (
        db.query(models.Subscription)
        .filter(models.Subscription.user_id == user.id)
        .order_by(models.Subscription.next_billing_date)
        .all()
    )


@router.post("", response_model=schemas.Subscription, status_code=201)
def create_subscription(
    payload: schemas.SubscriptionCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    _ensure_account_owned(payload.account_id, db, user)
    next_billing_date = advance(payload.last_payment_date, payload.billing_cycle)
    sub = models.Subscription(
        **payload.model_dump(), next_billing_date=next_billing_date, user_id=user.id
    )
    db.add(sub)
    db.commit()
    db.refresh(sub)
    return sub


def _get_owned_subscription(subscription_id: int, db: Session, user: models.User):
    sub = db.get(models.Subscription, subscription_id)
    if not sub or sub.user_id != user.id:
        raise HTTPException(status_code=404, detail="Subscription not found")
    return sub


@router.get("/{subscription_id}", response_model=schemas.Subscription)
def get_subscription(
    subscription_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    return _get_owned_subscription(subscription_id, db, user)


@router.put("/{subscription_id}", response_model=schemas.Subscription)
def update_subscription(
    subscription_id: int,
    payload: schemas.SubscriptionUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    sub = _get_owned_subscription(subscription_id, db, user)
    if payload.account_id is not None:
        _ensure_account_owned(payload.account_id, db, user)

    updates = payload.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(sub, field, value)

    if "last_payment_date" in updates or "billing_cycle" in updates:
        sub.next_billing_date = advance(sub.last_payment_date, sub.billing_cycle)

    db.commit()
    db.refresh(sub)
    return sub


@router.delete("/{subscription_id}", status_code=204)
def delete_subscription(
    subscription_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    sub = _get_owned_subscription(subscription_id, db, user)
    db.delete(sub)
    db.commit()
