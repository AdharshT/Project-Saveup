from datetime import date, datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict

BillingCycle = Literal["weekly", "monthly", "quarterly", "yearly"]
IncomeFrequency = Literal["weekly", "biweekly", "semimonthly", "monthly"]
PayType = Literal["fixed", "hourly"]


class UserCreate(BaseModel):
    name: str
    email: str
    password: str


class UserLogin(BaseModel):
    email: str
    password: str


class User(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    email: str


class AuthResponse(BaseModel):
    access_token: str
    user: User


class SubscriptionBase(BaseModel):
    name: str
    amount: float
    billing_cycle: BillingCycle
    category: Optional[str] = None
    next_billing_date: date
    active: bool = True
    notes: Optional[str] = None


class SubscriptionCreate(SubscriptionBase):
    pass


class SubscriptionUpdate(BaseModel):
    name: Optional[str] = None
    amount: Optional[float] = None
    billing_cycle: Optional[BillingCycle] = None
    category: Optional[str] = None
    next_billing_date: Optional[date] = None
    active: Optional[bool] = None
    notes: Optional[str] = None


class Subscription(SubscriptionBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: datetime


class IncomeBase(BaseModel):
    source: str
    amount: float
    frequency: IncomeFrequency
    pay_type: PayType = "fixed"
    hours_per_period: Optional[float] = None
    pay_period_start: Optional[date] = None
    pay_period_end: Optional[date] = None
    next_pay_date: date
    active: bool = True


class IncomeCreate(IncomeBase):
    pass


class IncomeUpdate(BaseModel):
    source: Optional[str] = None
    amount: Optional[float] = None
    frequency: Optional[IncomeFrequency] = None
    pay_type: Optional[PayType] = None
    hours_per_period: Optional[float] = None
    pay_period_start: Optional[date] = None
    pay_period_end: Optional[date] = None
    next_pay_date: Optional[date] = None
    active: Optional[bool] = None


class Income(IncomeBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: datetime


class TransactionBase(BaseModel):
    description: str
    amount: float
    category: Optional[str] = None
    date: date


class TransactionCreate(TransactionBase):
    pass


class TransactionUpdate(BaseModel):
    description: Optional[str] = None
    amount: Optional[float] = None
    category: Optional[str] = None
    date: Optional[date] = None


class Transaction(TransactionBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: datetime


class MonthlyTotal(BaseModel):
    month: str  # "YYYY-MM"
    total: float
    by_category: dict[str, float]


class MonthlyComparison(BaseModel):
    months: list[MonthlyTotal]


class NextPaycheck(BaseModel):
    source: str
    amount: float
    date: date


class AffordabilityRequest(BaseModel):
    item_name: str
    price: float


class AffordabilityResponse(BaseModel):
    item_name: str
    price: float
    can_afford: bool
    monthly_income: float
    monthly_subscription_cost: float
    spending_this_month: float
    discretionary_balance: float
    balance_after_purchase: float
    message: str
