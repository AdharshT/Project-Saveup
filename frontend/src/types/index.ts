export type BillingCycle = "weekly" | "monthly" | "quarterly" | "yearly";
export type IncomeFrequency = "weekly" | "biweekly" | "semimonthly" | "monthly";

export interface Subscription {
  id: number;
  name: string;
  amount: number;
  billing_cycle: BillingCycle;
  category: string | null;
  next_billing_date: string;
  active: boolean;
  notes: string | null;
  created_at: string;
}

export type SubscriptionInput = Omit<Subscription, "id" | "created_at">;

export interface Income {
  id: number;
  source: string;
  amount: number;
  frequency: IncomeFrequency;
  next_pay_date: string;
  active: boolean;
  created_at: string;
}

export type IncomeInput = Omit<Income, "id" | "created_at">;

export interface Transaction {
  id: number;
  description: string;
  amount: number;
  category: string | null;
  date: string;
  created_at: string;
}

export type TransactionInput = Omit<Transaction, "id" | "created_at">;

export interface NextPaycheck {
  source: string;
  amount: number;
  date: string;
}

export interface MonthlyTotal {
  month: string;
  total: number;
  by_category: Record<string, number>;
}

export interface MonthlyComparison {
  months: MonthlyTotal[];
}

export interface AffordabilityResponse {
  item_name: string;
  price: number;
  can_afford: boolean;
  monthly_income: number;
  monthly_subscription_cost: number;
  spending_this_month: number;
  discretionary_balance: number;
  balance_after_purchase: number;
  message: string;
}
