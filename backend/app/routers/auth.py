from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import create_access_token, get_current_user, hash_password, verify_password
from ..database import get_db

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=schemas.AuthResponse, status_code=201)
def signup(payload: schemas.UserCreate, db: Session = Depends(get_db)):
    email = payload.email.strip().lower()
    username = payload.username.strip()

    if db.query(models.User).filter(models.User.email == email).first():
        raise HTTPException(status_code=409, detail="An account with this email already exists.")
    if db.query(models.User).filter(func.lower(models.User.username) == username.lower()).first():
        raise HTTPException(status_code=409, detail="That username is already taken.")

    user = models.User(
        username=username,
        name=payload.name.strip(),
        email=email,
        password_hash=hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return schemas.AuthResponse(access_token=create_access_token(user.id), user=user)


@router.post("/login", response_model=schemas.AuthResponse)
def login(payload: schemas.UserLogin, db: Session = Depends(get_db)):
    email = payload.email.strip().lower()
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect email or password.")
    return schemas.AuthResponse(access_token=create_access_token(user.id), user=user)


@router.post("/reset-password", status_code=204)
def reset_password(payload: schemas.PasswordReset, db: Session = Depends(get_db)):
    email = payload.email.strip().lower()
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="No account found with this email.")

    user.password_hash = hash_password(payload.new_password)
    db.commit()


@router.get("/me", response_model=schemas.User)
def me(current_user: models.User = Depends(get_current_user)):
    return current_user
