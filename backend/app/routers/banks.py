from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import get_current_user
from ..database import get_db

router = APIRouter(prefix="/banks", tags=["banks"])


@router.get("", response_model=list[schemas.Bank])
def list_banks(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    return (
        db.query(models.Bank)
        .filter(models.Bank.user_id == user.id)
        .order_by(models.Bank.id)
        .all()
    )


@router.post("", response_model=schemas.Bank, status_code=201)
def create_bank(
    payload: schemas.BankCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    bank = models.Bank(**payload.model_dump(), user_id=user.id)
    db.add(bank)
    db.commit()
    db.refresh(bank)
    return bank


def _get_owned_bank(bank_id: int, db: Session, user: models.User) -> models.Bank:
    bank = db.get(models.Bank, bank_id)
    if not bank or bank.user_id != user.id:
        raise HTTPException(status_code=404, detail="Bank not found")
    return bank


@router.put("/{bank_id}", response_model=schemas.Bank)
def update_bank(
    bank_id: int,
    payload: schemas.BankUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    bank = _get_owned_bank(bank_id, db, user)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(bank, field, value)
    db.commit()
    db.refresh(bank)
    return bank


@router.delete("/{bank_id}", status_code=204)
def delete_bank(
    bank_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    bank = _get_owned_bank(bank_id, db, user)

    in_use = db.query(models.Account).filter(models.Account.bank_id == bank_id).first()
    if in_use:
        raise HTTPException(
            status_code=409,
            detail="This bank still has accounts assigned to it. Move or delete those first.",
        )

    db.delete(bank)
    db.commit()
