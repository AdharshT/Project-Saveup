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
import type { MonthlyComparison, Transaction } from "../types";

const emptyForm = {
  description: "",
  amount: "",
  category: "",
  date: new Date().toISOString().slice(0, 10),
};

export default function Spending() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [comparison, setComparison] = useState<MonthlyComparison | null>(null);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState<string | null>(null);

  const load = () =>
    Promise.all([api.transactions.list(), api.summary.monthly(6)]).then(([txns, monthly]) => {
      setTransactions(txns);
      setComparison(monthly);
    });

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
    try {
      await api.transactions.create({
        description: form.description,
        amount: parseFloat(form.amount),
        category: form.category || null,
        date: form.date,
      });
      setForm(emptyForm);
      await load();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  async function handleDelete(id: number) {
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
        <h3>Log Spending</h3>
        {error && <p className="error">{error}</p>}
        <div className="field-row">
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
            <input
              value={form.category}
              onChange={(e) => setForm({ ...form, category: e.target.value })}
              placeholder="Food"
            />
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
        <button type="submit">Add Transaction</button>
      </form>

      <div className="card" style={{ marginTop: "1rem" }}>
        <h3>Recent Transactions</h3>
        <table>
          <thead>
            <tr>
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
                <td>{t.date}</td>
                <td>{t.description}</td>
                <td>{t.category ?? "—"}</td>
                <td>${t.amount.toFixed(2)}</td>
                <td>
                  <button className="link-btn" onClick={() => handleDelete(t.id)}>
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {transactions.length === 0 && (
              <tr>
                <td colSpan={5} className="muted">
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
