from sqlalchemy import Boolean, Column, Date, DateTime, Float, Integer, String, func

from .database import Base


class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    amount = Column(Float, nullable=False)
    billing_cycle = Column(String, nullable=False)  # weekly | monthly | quarterly | yearly
    category = Column(String, nullable=True)
    next_billing_date = Column(Date, nullable=False)
    active = Column(Boolean, default=True, nullable=False)
    notes = Column(String, nullable=True)
    created_at = Column(DateTime, server_default=func.now())


class Income(Base):
    __tablename__ = "incomes"

    id = Column(Integer, primary_key=True, index=True)
    source = Column(String, nullable=False)
    amount = Column(Float, nullable=False)  # fixed: amount per paycheck; hourly: rate per hour
    frequency = Column(String, nullable=False)  # weekly | biweekly | semimonthly | monthly
    pay_type = Column(String, nullable=False, default="fixed")  # fixed | hourly
    hours_per_period = Column(Float, nullable=True)  # hours worked per pay period, hourly only
    pay_period_start = Column(Date, nullable=True)  # descriptive only, hourly
    pay_period_end = Column(Date, nullable=True)  # descriptive only, hourly
    next_pay_date = Column(Date, nullable=False)
    active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, server_default=func.now())


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    description = Column(String, nullable=False)
    amount = Column(Float, nullable=False)
    category = Column(String, nullable=True)
    date = Column(Date, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
