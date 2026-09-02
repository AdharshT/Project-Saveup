from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import engine
from .migrations import run_migrations
from .routers import (
    accounts,
    affordability,
    auth,
    banks,
    incomes,
    subscriptions,
    summary,
    transactions,
)

run_migrations(engine)

app = FastAPI(title="Budget Tracker API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(banks.router)
app.include_router(accounts.router)
app.include_router(subscriptions.router)
app.include_router(incomes.router)
app.include_router(transactions.router)
app.include_router(summary.router)
app.include_router(affordability.router)


@app.get("/health")
def health():
    return {"status": "ok"}
