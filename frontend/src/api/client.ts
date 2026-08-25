import type {
  AffordabilityResponse,
  AuthResponse,
  Income,
  IncomeInput,
  MonthlyComparison,
  NextPaycheck,
  Subscription,
  SubscriptionInput,
  Transaction,
  TransactionInput,
  User,
} from "../types";

const BASE_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8000";
const TOKEN_KEY = "saveup.token";

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
}

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const token = getToken();
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...options,
  });
  if (!res.ok) {
    let detail = await res.text();
    try {
      detail = JSON.parse(detail).detail ?? detail;
    } catch {
      // response wasn't JSON; fall back to the raw text
    }
    throw new Error(detail || `${options?.method ?? "GET"} ${path} failed: ${res.status}`);
  }
  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

export const api = {
  auth: {
    signup: (data: { name: string; email: string; password: string }) =>
      request<AuthResponse>("/auth/signup", { method: "POST", body: JSON.stringify(data) }),
    login: (data: { email: string; password: string }) =>
      request<AuthResponse>("/auth/login", { method: "POST", body: JSON.stringify(data) }),
    me: () => request<User>("/auth/me"),
  },
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
