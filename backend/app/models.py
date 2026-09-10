from sqlalchemy import Boolean, Column, Date, DateTime, Float, ForeignKey, Integer, String, func

from .database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(150), nullable=False, unique=True, index=True)
    name = Column(String(255), nullable=True)
    email = Column(String(255), nullable=False, unique=True, index=True)
    password_hash = Column(String(255), nullable=False)
    created_at = Column(DateTime, server_default=func.now())


class Bank(Base):
    __tablename__ = "banks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    created_at = Column(DateTime, server_default=func.now())


class Account(Base):
    __tablename__ = "accounts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    bank_id = Column(Integer, ForeignKey("banks.id"), nullable=True, index=True)
    nickname = Column(String(255), nullable=False)
    type = Column(String(20), nullable=True)  # checking | savings | credit
    last4 = Column(String(10), nullable=True)
    balance = Column(Float, nullable=False, default=0.0)
    created_at = Column(DateTime, server_default=func.now())


class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    account_id = Column(Integer, ForeignKey("accounts.id"), nullable=True, index=True)
    name = Column(String(255), nullable=False)
    amount = Column(Float, nullable=False)
    billing_cycle = Column(String(20), nullable=False)  # weekly | monthly | quarterly | yearly
    category = Column(String(100), nullable=True)
    last_payment_date = Column(Date, nullable=True)
    next_billing_date = Column(Date, nullable=False)
    active = Column(Boolean, default=True, nullable=False)
    notes = Column(String(1000), nullable=True)
    created_at = Column(DateTime, server_default=func.now())


class Income(Base):
    __tablename__ = "incomes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    account_id = Column(Integer, ForeignKey("accounts.id"), nullable=True, index=True)
    source = Column(String(255), nullable=False)
    amount = Column(Float, nullable=False)  # fixed: amount per paycheck; hourly: rate per hour
    frequency = Column(String(20), nullable=False)  # weekly | biweekly | semimonthly | monthly
    pay_type = Column(String(20), nullable=False, default="fixed")  # fixed | hourly
    hours_per_period = Column(Float, nullable=True)  # hours worked per pay period, hourly only
    pay_period_start = Column(Date, nullable=True)  # descriptive only, hourly
    pay_period_end = Column(Date, nullable=True)  # descriptive only, hourly
    next_pay_date = Column(Date, nullable=False)
    active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, server_default=func.now())


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    account_id = Column(Integer, ForeignKey("accounts.id"), nullable=True, index=True)
    description = Column(String(255), nullable=False)
    amount = Column(Float, nullable=False)
    category = Column(String(100), nullable=True)
    date = Column(Date, nullable=False)
    created_at = Column(DateTime, server_default=func.now())


class BasketCheck(Base):
    __tablename__ = "basket_checks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    total_price = Column(Float, nullable=False)
    can_afford = Column(Boolean, nullable=False)
    message = Column(String(500), nullable=False)
    monthly_income = Column(Float, nullable=False)
    monthly_subscription_cost = Column(Float, nullable=False)
    spending_this_month = Column(Float, nullable=False)
    discretionary_balance = Column(Float, nullable=False)
    balance_after_purchase = Column(Float, nullable=False)
    created_at = Column(DateTime, server_default=func.now())


class BasketCheckItem(Base):
    __tablename__ = "basket_check_items"

    id = Column(Integer, primary_key=True, index=True)
    basket_check_id = Column(Integer, ForeignKey("basket_checks.id"), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    price = Column(Float, nullable=False)
