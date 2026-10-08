from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import get_current_user
from ..database import get_db

router = APIRouter(prefix="/accounts", tags=["accounts"])


def _ensure_bank_owned(bank_id: int, db: Session, user: models.User):
    bank = db.get(models.Bank, bank_id)
    if not bank or bank.user_id != user.id:
        raise HTTPException(status_code=400, detail="Bank not found")


@router.get("", response_model=list[schemas.Account])
def list_accounts(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    return (
        db.query(models.Account)
        .filter(models.Account.user_id == user.id)
        .order_by(models.Account.id)
        .all()
    )


@router.post("", response_model=schemas.Account, status_code=201)
def create_account(
    payload: schemas.AccountCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    _ensure_bank_owned(payload.bank_id, db, user)
    account = models.Account(**payload.model_dump(), user_id=user.id)
    db.add(account)
    db.commit()
    db.refresh(account)
    return account


def _get_owned_account(account_id: int, db: Session, user: models.User) -> models.Account:
    account = db.get(models.Account, account_id)
    if not account or account.user_id != user.id:
        raise HTTPException(status_code=404, detail="Account not found")
    return account


@router.put("/{account_id}", response_model=schemas.Account)
def update_account(
    account_id: int,
    payload: schemas.AccountUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    account = _get_owned_account(account_id, db, user)
    if payload.bank_id is not None:
        _ensure_bank_owned(payload.bank_id, db, user)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(account, field, value)
    db.commit()
    db.refresh(account)
    return account


@router.delete("/{account_id}", status_code=204)
def delete_account(
    account_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    account = _get_owned_account(account_id, db, user)

    db.query(models.Transaction).filter(models.Transaction.account_id == account_id).delete(synchronize_session=False)
    db.query(models.Subscription).filter(models.Subscription.account_id == account_id).delete(synchronize_session=False)
    db.query(models.Income).filter(models.Income.account_id == account_id).delete(synchronize_session=False)

    db.delete(account)
    db.commit()
