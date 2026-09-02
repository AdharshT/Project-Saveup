import { type FormEvent, useEffect, useState } from "react";
import {
  Line,
  LineChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
  Legend,
} from "recharts";
import { api } from "../api/client";
import type { Account, MonthlyComparison, Transaction } from "../types";

const SPENDING_CATEGORIES = [
  { group: "Essentials", options: ["Food & Dining", "Transportation", "Vehicle"] },
  { group: "Lifestyle", options: ["Shopping", "Entertainment", "Tech & Gadgets", "Hobbies"] },
  { group: "Health", options: ["Fitness", "Medical", "Personal Care"] },
  { group: "Home", options: ["Household", "Home Improvement"] },
  { group: "Other", options: ["Travel", "Gifts & Donations", "Subscriptions", "Miscellaneous"] },
] as const;

const emptyForm = {
  account_id: "",
  description: "",
  amount: "",
  category: SPENDING_CATEGORIES[0].options[0] as string,
  date: new Date().toISOString().slice(0, 10),
};

export default function Spending() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [comparison, setComparison] = useState<MonthlyComparison | null>(null);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<number | null>(null);

  const load = () =>
    Promise.all([api.transactions.list(), api.summary.monthly(6), api.accounts.list()]).then(
      ([txns, monthly, accts]) => {
        setTransactions(txns);
        setComparison(monthly);
        setAccounts(accts);
        setForm((prev) =>
          prev.account_id || accts.length === 0
            ? prev
            : { ...prev, account_id: accts[0].id.toString() },
        );
      },
    );

  useEffect(() => {
    load().finally(() => setLoading(false));
  }, []);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (!form.description || !form.amount) {
      setError("Description and amount are required.");
      return;
    }
    if (!form.account_id) {
      setError("Add an account first.");
      return;
    }
    const payload = {
      account_id: parseInt(form.account_id, 10),
      description: form.description,
      amount: parseFloat(form.amount),
      category: form.category,
      date: form.date,
    };
    try {
      if (editingId !== null) {
        await api.transactions.update(editingId, payload);
        setEditingId(null);
      } else {
        await api.transactions.create(payload);
      }
      setForm(emptyForm);
      await load();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  function handleEdit(t: Transaction) {
    setEditingId(t.id);
    setError(null);
    setForm({
      account_id: t.account_id.toString(),
      description: t.description,
      amount: t.amount.toString(),
      category: t.category ?? SPENDING_CATEGORIES[0].options[0],
      date: t.date,
    });
  }

  function handleCancelEdit() {
    setEditingId(null);
    setError(null);
    setForm(emptyForm);
  }

  async function handleDelete(id: number) {
    if (id === editingId) handleCancelEdit();
    await api.transactions.remove(id);
    await load();
  }

  if (loading) return <p>Loading spending...</p>;

  const chartData = comparison?.months.map((m) => ({ month: m.month, total: m.total })) ?? [];

  return (
    <div>
      <h1>Spending</h1>

      <div className="card">
        <h3>Monthly Trend</h3>
        <ResponsiveContainer width="100%" height={260}>
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="month" />
            <YAxis />
            <Tooltip formatter={(value) => `$${Number(value).toFixed(2)}`} />
            <Legend />
            <Line type="monotone" dataKey="total" stroke="#2f7a4f" strokeWidth={2} />
          </LineChart>
        </ResponsiveContainer>
      </div>

      <form className="card form-grid" onSubmit={handleSubmit} style={{ marginTop: "1rem" }}>
        <h3>{editingId !== null ? "Edit Transaction" : "Log Spending"}</h3>
        {error && <p className="error">{error}</p>}
        {accounts.length === 0 && (
          <p className="muted">Add an account on the Accounts page before logging spending.</p>
        )}
        <div className="field-row">
          <label>
            Account
            <select
              value={form.account_id}
              onChange={(e) => setForm({ ...form, account_id: e.target.value })}
            >
              {accounts.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.nickname}
                </option>
              ))}
            </select>
          </label>
          <label>
            Description
            <input
              value={form.description}
              onChange={(e) => setForm({ ...form, description: e.target.value })}
              placeholder="Groceries"
            />
          </label>
          <label>
            Amount
            <input
              type="number"
              step="0.01"
              value={form.amount}
              onChange={(e) => setForm({ ...form, amount: e.target.value })}
              placeholder="45.20"
            />
          </label>
          <label>
            Category
            <select
              value={form.category}
              onChange={(e) => setForm({ ...form, category: e.target.value })}
            >
              {SPENDING_CATEGORIES.map((g) => (
                <optgroup key={g.group} label={g.group}>
                  {g.options.map((o) => (
                    <option key={o} value={o}>
                      {o}
                    </option>
                  ))}
                </optgroup>
              ))}
            </select>
          </label>
          <label>
            Date
            <input
              type="date"
              value={form.date}
              onChange={(e) => setForm({ ...form, date: e.target.value })}
            />
          </label>
        </div>
        <div className="field-row">
          <button type="submit">
            {editingId !== null ? "Save Changes" : "Add Transaction"}
          </button>
          {editingId !== null && (
            <button type="button" className="ghost-btn" onClick={handleCancelEdit}>
              Cancel
            </button>
          )}
        </div>
      </form>

      <div className="card" style={{ marginTop: "1rem" }}>
        <h3>Recent Transactions</h3>
        <table>
          <thead>
            <tr>
              <th>Account</th>
              <th>Date</th>
              <th>Description</th>
              <th>Category</th>
              <th>Amount</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {transactions.map((t) => (
              <tr key={t.id}>
                <td>{accounts.find((a) => a.id === t.account_id)?.nickname ?? "—"}</td>
                <td>{t.date}</td>
                <td>{t.description}</td>
                <td>{t.category ?? "—"}</td>
                <td>${t.amount.toFixed(2)}</td>
                <td>
                  <button className="link-btn link-btn-edit" onClick={() => handleEdit(t)}>
                    Edit
                  </button>
                  <button className="link-btn" onClick={() => handleDelete(t.id)}>
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {transactions.length === 0 && (
              <tr>
                <td colSpan={6} className="muted">
                  No transactions yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
