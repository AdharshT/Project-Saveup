export interface User {
  id: number;
  username: string;
  name: string;
  email: string;
}

export interface AuthResponse {
  access_token: string;
  user: User;
}

export type BillingCycle = "weekly" | "monthly" | "quarterly" | "yearly";
export type IncomeFrequency = "weekly" | "biweekly" | "semimonthly" | "monthly";
export type PayType = "fixed" | "hourly";

export interface Bank {
  id: number;
  name: string;
  created_at: string;
}

export type BankInput = Omit<Bank, "id" | "created_at">;

export type AccountType = "checking" | "savings" | "credit";

export interface Account {
  id: number;
  bank_id: number;
  nickname: string;
  type: AccountType | null;
  last4: string | null;
  balance: number;
  created_at: string;
}

export type AccountInput = Omit<Account, "id" | "created_at">;

export interface Subscription {
  id: number;
  account_id: number;
  name: string;
  amount: number;
  billing_cycle: BillingCycle;
  category: string | null;
  last_payment_date: string;
  next_billing_date: string;
  active: boolean;
  notes: string | null;
  created_at: string;
}

export type SubscriptionInput = Omit<Subscription, "id" | "created_at" | "next_billing_date">;

export interface Income {
  id: number;
  account_id: number;
  source: string;
  amount: number;
  frequency: IncomeFrequency;
  pay_type: PayType;
  hours_per_period: number | null;
  pay_period_start: string | null;
  pay_period_end: string | null;
  next_pay_date: string;
  active: boolean;
  created_at: string;
}

export type IncomeInput = Omit<Income, "id" | "created_at">;

export interface Transaction {
  id: number;
  account_id: number;
  description: string;
  amount: number;
  category: string | null;
  date: string;
  created_at: string;
}

export type TransactionInput = Omit<Transaction, "id" | "created_at">;

export interface NextPaycheck {
  account_id: number;
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

export interface BasketItemInput {
  name: string;
  price: number;
}

export interface BasketItem extends BasketItemInput {
  id: number;
}

export interface AffordabilityResponse {
  id: number;
  items: BasketItem[];
  total_price: number;
  can_afford: boolean;
  monthly_income: number;
  monthly_subscription_cost: number;
  spending_this_month: number;
  discretionary_balance: number;
  balance_after_purchase: number;
  message: string;
  created_at: string;
}
