from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import models
from .database import engine
from .routers import affordability, incomes, subscriptions, summary, transactions

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Budget Tracker API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(subscriptions.router)
app.include_router(incomes.router)
app.include_router(transactions.router)
app.include_router(summary.router)
app.include_router(affordability.router)


@app.get("/health")
def health():
    return {"status": "ok"}
