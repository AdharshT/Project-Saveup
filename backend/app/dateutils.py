from datetime import date

from dateutil.relativedelta import relativedelta


def advance(d: date, cycle: str) -> date:
    """Return the next occurrence of a recurring date given a cycle name."""
    if cycle == "weekly":
        return d + relativedelta(weeks=1)
    if cycle == "biweekly":
        return d + relativedelta(weeks=2)
    if cycle == "semimonthly":
        return d + relativedelta(days=15)
    if cycle == "monthly":
        return d + relativedelta(months=1)
    if cycle == "quarterly":
        return d + relativedelta(months=3)
    if cycle == "yearly":
        return d + relativedelta(years=1)
    raise ValueError(f"Unknown cycle: {cycle}")


def next_occurrence_on_or_after(start: date, reference: date, cycle: str) -> date:
    """Roll `start` forward by `cycle` until it lands on or after `reference`."""
    occurrence = start
    while occurrence < reference:
        occurrence = advance(occurrence, cycle)
    return occurrence


def monthly_equivalent(amount: float, cycle: str) -> float:
    """Normalize a recurring amount to an average monthly cost."""
    factors = {
        "weekly": 52 / 12,
        "biweekly": 26 / 12,
        "semimonthly": 2,
        "monthly": 1,
        "quarterly": 1 / 3,
        "yearly": 1 / 12,
    }
    return amount * factors[cycle]
