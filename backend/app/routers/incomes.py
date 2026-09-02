from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import get_current_user
from ..database import get_db
from ..dateutils import effective_income_amount, next_occurrence_on_or_after

router = APIRouter(prefix="/incomes", tags=["incomes"])


def _ensure_account_owned(account_id: int, db: Session, user: models.User):
    account = db.get(models.Account, account_id)
    if not account or account.user_id != user.id:
        raise HTTPException(status_code=400, detail="Account not found")


@router.get("", response_model=list[schemas.Income])
def list_incomes(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    return (
        db.query(models.Income)
        .filter(models.Income.user_id == user.id)
        .order_by(models.Income.next_pay_date)
        .all()
    )


@router.post("", response_model=schemas.Income, status_code=201)
def create_income(
    payload: schemas.IncomeCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    _ensure_account_owned(payload.account_id, db, user)
    income = models.Income(**payload.model_dump(), user_id=user.id)
    db.add(income)
    db.commit()
    db.refresh(income)
    return income


def _get_owned_income(income_id: int, db: Session, user: models.User):
    income = db.get(models.Income, income_id)
    if not income or income.user_id != user.id:
        raise HTTPException(status_code=404, detail="Income not found")
    return income


@router.get("/{income_id}", response_model=schemas.Income)
def get_income(
    income_id: int, db: Session = Depends(get_db), user: models.User = Depends(get_current_user)
):
    return _get_owned_income(income_id, db, user)


@router.put("/{income_id}", response_model=schemas.Income)
def update_income(
    income_id: int,
    payload: schemas.IncomeUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    income = _get_owned_income(income_id, db, user)
    if payload.account_id is not None:
        _ensure_account_owned(payload.account_id, db, user)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(income, field, value)
    db.commit()
    db.refresh(income)
    return income


@router.delete("/{income_id}", status_code=204)
def delete_income(
    income_id: int, db: Session = Depends(get_db), user: models.User = Depends(get_current_user)
):
    income = _get_owned_income(income_id, db, user)
    db.delete(income)
    db.commit()


@router.get("/upcoming/next", response_model=list[schemas.NextPaycheck])
def next_paychecks(
    db: Session = Depends(get_db), user: models.User = Depends(get_current_user)
):
    today = date.today()
    incomes = (
        db.query(models.Income)
        .filter(models.Income.user_id == user.id, models.Income.active.is_(True))
        .all()
    )
    results = []
    for income in incomes:
        next_date = next_occurrence_on_or_after(income.next_pay_date, today, income.frequency)
        amount = effective_income_amount(income.amount, income.pay_type, income.hours_per_period)
        results.append(
            schemas.NextPaycheck(
                account_id=income.account_id, source=income.source, amount=amount, date=next_date
            )
        )
    return sorted(results, key=lambda r: r.date)
