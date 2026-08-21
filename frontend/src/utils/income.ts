import type { Income } from "../types";

export function effectiveIncomeAmount(
  income: Pick<Income, "amount" | "pay_type" | "hours_per_period">,
): number {
  if (income.pay_type === "hourly") {
    return income.amount * (income.hours_per_period ?? 0);
  }
  return income.amount;
}
