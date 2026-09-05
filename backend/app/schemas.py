from datetime import date, date as date_type, datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

BillingCycle = Literal["weekly", "monthly", "quarterly", "yearly"]
IncomeFrequency = Literal["weekly", "biweekly", "semimonthly", "monthly"]
PayType = Literal["fixed", "hourly"]
AccountType = Literal["checking", "savings", "credit"]

USERNAME_PATTERN = r"^[a-zA-Z0-9_]+$"


class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=20, pattern=USERNAME_PATTERN)
    name: str = Field(min_length=1, max_length=100)
    email: str
    password: str


class UserLogin(BaseModel):
    email: str
    password: str


class PasswordReset(BaseModel):
    email: str
    new_password: str


class User(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    username: str
    name: str
    email: str


class AuthResponse(BaseModel):
    access_token: str
    user: User


class BankBase(BaseModel):
    name: str


class BankCreate(BankBase):
    pass


class BankUpdate(BaseModel):
    name: Optional[str] = None


class Bank(BankBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: datetime


class AccountBase(BaseModel):
    bank_id: int
    nickname: str
    type: Optional[AccountType] = None
    last4: Optional[str] = None
    balance: float = 0.0


class AccountCreate(AccountBase):
    pass


class AccountUpdate(BaseModel):
    bank_id: Optional[int] = None
    nickname: Optional[str] = None
    type: Optional[AccountType] = None
    last4: Optional[str] = None
    balance: Optional[float] = None


class Account(AccountBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: datetime


class SubscriptionBase(BaseModel):
    account_id: int
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
    account_id: Optional[int] = None
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
    account_id: int
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
    account_id: Optional[int] = None
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
    account_id: int
    description: str
    amount: float
    category: Optional[str] = None
    date: date


class TransactionCreate(TransactionBase):
    pass


class TransactionUpdate(BaseModel):
    account_id: Optional[int] = None
    description: Optional[str] = None
    amount: Optional[float] = None
    category: Optional[str] = None
    date: Optional[date_type] = None


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
    account_id: int
    source: str
    amount: float
    date: date


class BasketItemInput(BaseModel):
    name: str
    price: float


class BasketItem(BasketItemInput):
    model_config = ConfigDict(from_attributes=True)
    id: int


class AffordabilityRequest(BaseModel):
    items: list[BasketItemInput]


class AffordabilityResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    items: list[BasketItem]
    total_price: float
    can_afford: bool
    monthly_income: float
    monthly_subscription_cost: float
    spending_this_month: float
    discretionary_balance: float
    balance_after_purchase: float
    message: str
    created_at: datetime
