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
