import { type FormEvent, useEffect, useState } from "react";
import { api } from "../api/client";
import type { Account, Income, IncomeFrequency, NextPaycheck, PayType } from "../types";
import { effectiveIncomeAmount } from "../utils/income";

const FREQUENCIES: IncomeFrequency[] = ["Weekly", "Biweekly", "Semimonthly", "Monthly"];

const emptyForm = {
  account_id: "",
  source: "",
  amount: "",
  frequency: "Biweekly" as IncomeFrequency,
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
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<number | null>(null);

  const load = () =>
    Promise.all([api.incomes.list(), api.incomes.next(), api.accounts.list()]).then(
      ([inc, next, accts]) => {
        setIncomes(inc);
        setNextPaychecks(next);
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
    if (!form.source || !form.amount) {
      setError("Source and amount are required.");
      return;
    }
    if (form.pay_type === "Hourly" && !form.hours_per_period) {
      setError("Hours per pay period is required for hourly pay.");
      return;
    }
    if (!form.account_id) {
      setError("Add an account first.");
      return;
    }
    const payload = {
      account_id: parseInt(form.account_id, 10),
      source: form.source,
      amount: parseFloat(form.amount),
      frequency: form.frequency,
      pay_type: form.pay_type,
      hours_per_period:
        form.pay_type === "Hourly" ? parseFloat(form.hours_per_period) : null,
      pay_period_start:
        form.pay_type === "Hourly" && form.pay_period_start ? form.pay_period_start : null,
      pay_period_end:
        form.pay_type === "Hourly" && form.pay_period_end ? form.pay_period_end : null,
      next_pay_date: form.next_pay_date,
      active: form.active,
    };
    try {
      if (editingId !== null) {
        await api.incomes.update(editingId, payload);
        setEditingId(null);
      } else {
        await api.incomes.create(payload);
      }
      setForm(emptyForm);
      await load();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  function handleEdit(income: Income) {
    setEditingId(income.id);
    setError(null);
    setForm({
      account_id: income.account_id.toString(),
      source: income.source,
      amount: income.amount.toString(),
      frequency: income.frequency,
      pay_type: income.pay_type,
      hours_per_period: income.hours_per_period?.toString() ?? "",
      pay_period_start: income.pay_period_start ?? "",
      pay_period_end: income.pay_period_end ?? "",
      next_pay_date: income.next_pay_date,
      active: income.active,
    });
  }

  function handleCancelEdit() {
    setEditingId(null);
    setError(null);
    setForm(emptyForm);
  }

  async function handleDelete(id: number) {
    if (id === editingId) handleCancelEdit();
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
        <h3>{editingId !== null ? "Edit Income Source" : "Add Income Source"}</h3>
        {error && <p className="error">{error}</p>}
        {accounts.length === 0 && (
          <p className="muted">
            Add an account on the Accounts page before adding income sources.
          </p>
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
            {form.pay_type === "Hourly" ? "Hourly Rate" : "Amount"}
            <input
              type="number"
              step="0.01"
              value={form.amount}
              onChange={(e) => setForm({ ...form, amount: e.target.value })}
              placeholder={form.pay_type === "Hourly" ? "17.50" : "2500"}
            />
          </label>
          {form.pay_type === "Hourly" && (
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
          {form.pay_type === "Hourly" && (
            <label>
              Pay Period Start
              <input
                type="date"
                value={form.pay_period_start}
                onChange={(e) => setForm({ ...form, pay_period_start: e.target.value })}
              />
            </label>
          )}
          {form.pay_type === "Hourly" && (
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
        {form.pay_type === "Hourly" && form.amount && form.hours_per_period && (
          <p className="muted">
            = ${(parseFloat(form.amount) * parseFloat(form.hours_per_period)).toFixed(2)} per
            paycheck at {form.frequency} frequency
          </p>
        )}
        <div className="field-row">
          <button type="submit">
            {editingId !== null ? "Save Changes" : "Add Income"}
          </button>
          {editingId !== null && (
            <button type="button" className="ghost-btn" onClick={handleCancelEdit}>
              Cancel
            </button>
          )}
        </div>
      </form>

      <div className="card" style={{ marginTop: "1rem" }}>
        <h3>All Income Sources</h3>
        <table>
          <thead>
            <tr>
              <th>Account</th>
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
                <td>{accounts.find((a) => a.id === i.account_id)?.nickname ?? "—"}</td>
                <td>{i.source}</td>
                <td>
                  ${effectiveIncomeAmount(i).toFixed(2)}
                  {i.pay_type === "Hourly" && (
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
                  <button className="link-btn link-btn-edit" onClick={() => handleEdit(i)}>
                    Edit
                  </button>
                  <button className="link-btn" onClick={() => handleDelete(i.id)}>
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {incomes.length === 0 && (
              <tr>
                <td colSpan={7} className="muted">
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
