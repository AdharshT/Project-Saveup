import { type FormEvent, useEffect, useState } from "react";
import { api } from "../api/client";
import type { Income, IncomeFrequency, NextPaycheck } from "../types";

const FREQUENCIES: IncomeFrequency[] = ["weekly", "biweekly", "semimonthly", "monthly"];

const emptyForm = {
  source: "",
  amount: "",
  frequency: "biweekly" as IncomeFrequency,
  next_pay_date: new Date().toISOString().slice(0, 10),
  active: true,
};

export default function IncomePage() {
  const [incomes, setIncomes] = useState<Income[]>([]);
  const [nextPaychecks, setNextPaychecks] = useState<NextPaycheck[]>([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState<string | null>(null);

  const load = () =>
    Promise.all([api.incomes.list(), api.incomes.next()]).then(([inc, next]) => {
      setIncomes(inc);
      setNextPaychecks(next);
    });

  useEffect(() => {
    load().finally(() => setLoading(false));
  }, []);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (!form.source || !form.amount) {
      setError("Source and amount are required.");
      return;
    }
    try {
      await api.incomes.create({
        source: form.source,
        amount: parseFloat(form.amount),
        frequency: form.frequency,
        next_pay_date: form.next_pay_date,
        active: form.active,
      });
      setForm(emptyForm);
      await load();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  async function handleDelete(id: number) {
    await api.incomes.remove(id);
    await load();
  }

  if (loading) return <p>Loading income...</p>;

  return (
    <div>
      <h1>Income</h1>

      <div className="card">
        <h3>Upcoming Paychecks</h3>
        {nextPaychecks.length === 0 && <p className="muted">No income sources yet.</p>}
        <ul className="plain-list">
          {nextPaychecks.map((p, idx) => (
            <li key={idx}>
              <strong>${p.amount.toFixed(2)}</strong> from {p.source} on {p.date}
            </li>
          ))}
        </ul>
      </div>

      <form className="card form-grid" onSubmit={handleSubmit} style={{ marginTop: "1rem" }}>
        <h3>Add Income Source</h3>
        {error && <p className="error">{error}</p>}
        <div className="field-row">
          <label>
            Source
            <input
              value={form.source}
              onChange={(e) => setForm({ ...form, source: e.target.value })}
              placeholder="Main Job"
            />
          </label>
          <label>
            Amount
            <input
              type="number"
              step="0.01"
              value={form.amount}
              onChange={(e) => setForm({ ...form, amount: e.target.value })}
              placeholder="2500"
            />
          </label>
          <label>
            Frequency
            <select
              value={form.frequency}
              onChange={(e) =>
                setForm({ ...form, frequency: e.target.value as IncomeFrequency })
              }
            >
              {FREQUENCIES.map((f) => (
                <option key={f} value={f}>
                  {f}
                </option>
              ))}
            </select>
          </label>
          <label>
            Next Pay Date
            <input
              type="date"
              value={form.next_pay_date}
              onChange={(e) => setForm({ ...form, next_pay_date: e.target.value })}
            />
          </label>
        </div>
        <button type="submit">Add Income</button>
      </form>

      <div className="card" style={{ marginTop: "1rem" }}>
        <h3>All Income Sources</h3>
        <table>
          <thead>
            <tr>
              <th>Source</th>
              <th>Amount</th>
              <th>Frequency</th>
              <th>Next Pay Date</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {incomes.map((i) => (
              <tr key={i.id}>
                <td>{i.source}</td>
                <td>${i.amount.toFixed(2)}</td>
                <td>{i.frequency}</td>
                <td>{i.next_pay_date}</td>
                <td>
                  <button className="link-btn" onClick={() => handleDelete(i.id)}>
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {incomes.length === 0 && (
              <tr>
                <td colSpan={5} className="muted">
                  No income sources yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
