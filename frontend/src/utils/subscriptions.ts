const MONTHLY_FACTORS: Record<string, number> = {
  weekly: 52 / 12,
  biweekly: 26 / 12,
  semimonthly: 2,
  monthly: 1,
  quarterly: 1 / 3,
  yearly: 1 / 12,
};

export function monthlyEquivalent(amount: number, cycle: string): number {
  return amount * (MONTHLY_FACTORS[cycle] ?? 1);
}

function parseISODate(dateStr: string): Date {
  const [year, month, day] = dateStr.split("-").map(Number);
  return new Date(year, month - 1, day);
}

function stepBack(date: Date, cycle: string): Date {
  const d = new Date(date);
  switch (cycle) {
    case "weekly":
      d.setDate(d.getDate() - 7);
      break;
    case "quarterly":
      d.setMonth(d.getMonth() - 3);
      break;
    case "yearly":
      d.setFullYear(d.getFullYear() - 1);
      break;
    default:
      d.setMonth(d.getMonth() - 1);
  }
  return d;
}

function toISODate(d: Date): string {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/**
 * Preview of the next billing date, one cycle after the given date.
 * Mirrors the backend's authoritative calculation for display purposes only.
 */
export function addBillingInterval(dateStr: string, cycle: string): string {
  const d = parseISODate(dateStr);
  switch (cycle) {
    case "weekly":
      d.setDate(d.getDate() + 7);
      break;
    case "quarterly":
      d.setMonth(d.getMonth() + 3);
      break;
    case "yearly":
      d.setFullYear(d.getFullYear() + 1);
      break;
    default:
      d.setMonth(d.getMonth() + 1);
  }
  return toISODate(d);
}

/**
 * How much of this subscription is actually billed within the given month,
 * accounting for cycles (like quarterly/yearly) that don't bill every month.
 */
export function amountDueInMonth(
  amount: number,
  cycle: string,
  nextBillingDate: string,
  monthStr: string,
): number {
  const [year, month] = monthStr.split("-").map(Number);
  const monthStart = new Date(year, month - 1, 1);
  const monthEnd = new Date(year, month, 0);

  let cursor = parseISODate(nextBillingDate);
  let iterations = 0;
  while (cursor > monthEnd && iterations < 1000) {
    cursor = stepBack(cursor, cycle);
    iterations++;
  }

  let occurrences = 0;
  while (cursor >= monthStart && iterations < 2000) {
    if (cursor <= monthEnd) occurrences++;
    cursor = stepBack(cursor, cycle);
    iterations++;
  }

  return occurrences * amount;
}
