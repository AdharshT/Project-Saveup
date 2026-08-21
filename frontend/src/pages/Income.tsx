import { type FormEvent, useEffect, useState } from "react";
import { api } from "../api/client";
import type { Income, IncomeFrequency, NextPaycheck, PayType } from "../types";
import { effectiveIncomeAmount } from "../utils/income";

const FREQUENCIES: IncomeFrequency[] = ["weekly", "biweekly", "semimonthly", "monthly"];

const emptyForm = {
  source: "",
  amount: "",
  frequency: "biweekly" as IncomeFrequency,
  pay_type: "fixed" as PayType,
  hours_per_period: "",
  pay_period_start: "",
  pay_period_end: "",
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
    if (form.pay_type === "hourly" && !form.hours_per_period) {
      setError("Hours per pay period is required for hourly pay.");
      return;
    }
    try {
      await api.incomes.create({
        source: form.source,
        amount: parseFloat(form.amount),
        frequency: form.frequency,
        pay_type: form.pay_type,
        hours_per_period:
          form.pay_type === "hourly" ? parseFloat(form.hours_per_period) : null,
        pay_period_start:
          form.pay_type === "hourly" && form.pay_period_start ? form.pay_period_start : null,
        pay_period_end:
          form.pay_type === "hourly" && form.pay_period_end ? form.pay_period_end : null,
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
            Pay Type
            <select
              value={form.pay_type}
              onChange={(e) =>
                setForm({
                  ...form,
                  pay_type: e.target.value as PayType,
                  hours_per_period: "",
                  pay_period_start: "",
                  pay_period_end: "",
                })
              }
            >
              <option value="fixed">Fixed amount</option>
              <option value="hourly">Hourly</option>
            </select>
          </label>
          <label>
            {form.pay_type === "hourly" ? "Hourly Rate" : "Amount"}
            <input
              type="number"
              step="0.01"
              value={form.amount}
              onChange={(e) => setForm({ ...form, amount: e.target.value })}
              placeholder={form.pay_type === "hourly" ? "17.50" : "2500"}
            />
          </label>
          {form.pay_type === "hourly" && (
            <label>
              Hours per Pay Period
              <input
                type="number"
                step="0.1"
                value={form.hours_per_period}
                onChange={(e) => setForm({ ...form, hours_per_period: e.target.value })}
                placeholder="64"
              />
            </label>
          )}
          {form.pay_type === "hourly" && (
            <label>
              Pay Period Start
              <input
                type="date"
                value={form.pay_period_start}
                onChange={(e) => setForm({ ...form, pay_period_start: e.target.value })}
              />
            </label>
          )}
          {form.pay_type === "hourly" && (
            <label>
              Pay Period End
              <input
                type="date"
                value={form.pay_period_end}
                onChange={(e) => setForm({ ...form, pay_period_end: e.target.value })}
              />
            </label>
          )}
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
        {form.pay_type === "hourly" && form.amount && form.hours_per_period && (
          <p className="muted">
            = ${(parseFloat(form.amount) * parseFloat(form.hours_per_period)).toFixed(2)} per
            paycheck at {form.frequency} frequency
          </p>
        )}
        <button type="submit">Add Income</button>
      </form>

      <div className="card" style={{ marginTop: "1rem" }}>
        <h3>All Income Sources</h3>
        <table>
          <thead>
            <tr>
              <th>Source</th>
              <th>Amount</th>
              <th>Pay Period</th>
              <th>Frequency</th>
              <th>Next Pay Date</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {incomes.map((i) => (
              <tr key={i.id}>
                <td>{i.source}</td>
                <td>
                  ${effectiveIncomeAmount(i).toFixed(2)}
                  {i.pay_type === "hourly" && (
                    <span className="muted">
                      {" "}
                      (${i.amount.toFixed(2)}/hr &times; {i.hours_per_period}hr)
                    </span>
                  )}
                </td>
                <td>
                  {i.pay_period_start && i.pay_period_end
                    ? `${i.pay_period_start} - ${i.pay_period_end}`
                    : <span className="muted">—</span>}
                </td>
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
                <td colSpan={6} className="muted">
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
