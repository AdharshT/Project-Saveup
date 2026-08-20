import type {
  AffordabilityResponse,
  Income,
  IncomeInput,
  MonthlyComparison,
  NextPaycheck,
  Subscription,
  SubscriptionInput,
  Transaction,
  TransactionInput,
} from "../types";

const BASE_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8000";

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`${options?.method ?? "GET"} ${path} failed: ${res.status} ${body}`);
  }
  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

export const api = {
  subscriptions: {
    list: () => request<Subscription[]>("/subscriptions"),
    create: (data: SubscriptionInput) =>
      request<Subscription>("/subscriptions", { method: "POST", body: JSON.stringify(data) }),
    update: (id: number, data: Partial<SubscriptionInput>) =>
      request<Subscription>(`/subscriptions/${id}`, {
        method: "PUT",
        body: JSON.stringify(data),
      }),
    remove: (id: number) => request<void>(`/subscriptions/${id}`, { method: "DELETE" }),
  },
  incomes: {
    list: () => request<Income[]>("/incomes"),
    create: (data: IncomeInput) =>
      request<Income>("/incomes", { method: "POST", body: JSON.stringify(data) }),
    update: (id: number, data: Partial<IncomeInput>) =>
      request<Income>(`/incomes/${id}`, { method: "PUT", body: JSON.stringify(data) }),
    remove: (id: number) => request<void>(`/incomes/${id}`, { method: "DELETE" }),
    next: () => request<NextPaycheck[]>("/incomes/upcoming/next"),
  },
  transactions: {
    list: () => request<Transaction[]>("/transactions"),
    create: (data: TransactionInput) =>
      request<Transaction>("/transactions", { method: "POST", body: JSON.stringify(data) }),
    update: (id: number, data: Partial<TransactionInput>) =>
      request<Transaction>(`/transactions/${id}`, {
        method: "PUT",
        body: JSON.stringify(data),
      }),
    remove: (id: number) => request<void>(`/transactions/${id}`, { method: "DELETE" }),
  },
  summary: {
    monthly: (months = 6) =>
      request<MonthlyComparison>(`/summary/monthly?months=${months}`),
  },
  affordability: {
    check: (item_name: string, price: number) =>
      request<AffordabilityResponse>("/affordability/check", {
        method: "POST",
        body: JSON.stringify({ item_name, price }),
      }),
  },
};
