import os
import ssl

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

SQLALCHEMY_DATABASE_URL = os.environ.get(
    "SAVEUP_DATABASE_URL", "sqlite:///./budget.db"
)

# Use pg8000 driver for PostgreSQL (pure Python, no compilation needed)
if SQLALCHEMY_DATABASE_URL.startswith("postgresql://"):
    SQLALCHEMY_DATABASE_URL = SQLALCHEMY_DATABASE_URL.replace(
        "postgresql://", "postgresql+pg8000://", 1
    )

if SQLALCHEMY_DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}
elif SQLALCHEMY_DATABASE_URL.startswith("postgresql+pg8000"):
    ssl_context = ssl.create_default_context()
    ssl_context.check_hostname = False
    ssl_context.verify_mode = ssl.CERT_NONE
    connect_args = {"ssl_context": ssl_context}
else:
    connect_args = {}
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
