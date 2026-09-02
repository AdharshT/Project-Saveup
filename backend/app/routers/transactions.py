from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import get_current_user
from ..database import get_db

router = APIRouter(prefix="/transactions", tags=["transactions"])


def _ensure_account_owned(account_id: int, db: Session, user: models.User):
    account = db.get(models.Account, account_id)
    if not account or account.user_id != user.id:
        raise HTTPException(status_code=400, detail="Account not found")


@router.get("", response_model=list[schemas.Transaction])
def list_transactions(
    db: Session = Depends(get_db), user: models.User = Depends(get_current_user)
):
    return (
        db.query(models.Transaction)
        .filter(models.Transaction.user_id == user.id)
        .order_by(models.Transaction.date.desc())
        .all()
    )


@router.post("", response_model=schemas.Transaction, status_code=201)
def create_transaction(
    payload: schemas.TransactionCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    _ensure_account_owned(payload.account_id, db, user)
    txn = models.Transaction(**payload.model_dump(), user_id=user.id)
    db.add(txn)
    db.commit()
    db.refresh(txn)
    return txn


def _get_owned_transaction(transaction_id: int, db: Session, user: models.User):
    txn = db.get(models.Transaction, transaction_id)
    if not txn or txn.user_id != user.id:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return txn


@router.get("/{transaction_id}", response_model=schemas.Transaction)
def get_transaction(
    transaction_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    return _get_owned_transaction(transaction_id, db, user)


@router.put("/{transaction_id}", response_model=schemas.Transaction)
def update_transaction(
    transaction_id: int,
    payload: schemas.TransactionUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    txn = _get_owned_transaction(transaction_id, db, user)
    if payload.account_id is not None:
        _ensure_account_owned(payload.account_id, db, user)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(txn, field, value)
    db.commit()
    db.refresh(txn)
    return txn


@router.delete("/{transaction_id}", status_code=204)
def delete_transaction(
    transaction_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    txn = _get_owned_transaction(transaction_id, db, user)
    db.delete(txn)
    db.commit()
