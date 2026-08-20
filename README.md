# Project-Saveup

A Rocket Money-style app for tracking subscriptions, paycheck income, monthly spending, and whether you can afford a purchase. Data is entered manually — no bank account linking.

## Stack

- **Backend**: Python, FastAPI, SQLAlchemy, SQLite
- **Frontend**: React, TypeScript, Vite, React Router, Recharts

## Features

- **Subscriptions** — track recurring costs (weekly/monthly/quarterly/yearly), see total active monthly cost.
- **Income** — add one or more income sources with a pay frequency, see the next upcoming paycheck(s).
- **Spending** — log transactions by category and date, view month-over-month totals and a trend chart.
- **Can I Afford This?** — check whether a purchase fits your discretionary budget (income minus subscriptions minus spending so far this month).

## Getting Started

### Backend

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

The API runs at `http://localhost:8000`. Interactive docs at `http://localhost:8000/docs`. Data is stored in `backend/budget.db` (SQLite), created automatically on first run.

### Frontend

```bash
cd frontend
npm install
npm run dev
```

The app runs at `http://localhost:5173` and talks to the backend at `http://localhost:8000` (override with a `VITE_API_URL` env var).

## Project Structure

```
my-project/
├── backend/
│   └── app/
│       ├── main.py        # FastAPI app, CORS, router registration
│       ├── models.py      # SQLAlchemy models
│       ├── schemas.py     # Pydantic request/response schemas
│       ├── database.py    # SQLite engine/session
│       ├── dateutils.py   # recurring-date math
│       └── routers/       # subscriptions, incomes, transactions, summary, affordability
├── frontend/
│   └── src/
│       ├── api/client.ts  # typed fetch wrapper for the backend
│       ├── pages/         # Dashboard, Subscriptions, Income, Spending, Affordability
│       └── types/         # shared TypeScript types
└── README.md
```

## Notes

- Requires Node.js 20.19+ or 22.12+ for Vite. Node 20.14 will run but prints a warning.
