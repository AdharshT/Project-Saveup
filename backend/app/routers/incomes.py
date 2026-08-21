from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db
from ..dateutils import effective_income_amount, next_occurrence_on_or_after

router = APIRouter(prefix="/incomes", tags=["incomes"])


@router.get("", response_model=list[schemas.Income])
def list_incomes(db: Session = Depends(get_db)):
    return db.query(models.Income).order_by(models.Income.next_pay_date).all()


@router.post("", response_model=schemas.Income, status_code=201)
def create_income(payload: schemas.IncomeCreate, db: Session = Depends(get_db)):
    income = models.Income(**payload.model_dump())
    db.add(income)
    db.commit()
    db.refresh(income)
    return income


@router.get("/{income_id}", response_model=schemas.Income)
def get_income(income_id: int, db: Session = Depends(get_db)):
    income = db.get(models.Income, income_id)
    if not income:
        raise HTTPException(status_code=404, detail="Income not found")
    return income


@router.put("/{income_id}", response_model=schemas.Income)
def update_income(income_id: int, payload: schemas.IncomeUpdate, db: Session = Depends(get_db)):
    income = db.get(models.Income, income_id)
    if not income:
        raise HTTPException(status_code=404, detail="Income not found")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(income, field, value)
    db.commit()
    db.refresh(income)
    return income


@router.delete("/{income_id}", status_code=204)
def delete_income(income_id: int, db: Session = Depends(get_db)):
    income = db.get(models.Income, income_id)
    if not income:
        raise HTTPException(status_code=404, detail="Income not found")
    db.delete(income)
    db.commit()


@router.get("/upcoming/next", response_model=list[schemas.NextPaycheck])
def next_paychecks(db: Session = Depends(get_db)):
    today = date.today()
    incomes = db.query(models.Income).filter(models.Income.active.is_(True)).all()
    results = []
    for income in incomes:
        next_date = next_occurrence_on_or_after(income.next_pay_date, today, income.frequency)
        amount = effective_income_amount(income.amount, income.pay_type, income.hours_per_period)
        results.append(
            schemas.NextPaycheck(source=income.source, amount=amount, date=next_date)
        )
    return sorted(results, key=lambda r: r.date)
