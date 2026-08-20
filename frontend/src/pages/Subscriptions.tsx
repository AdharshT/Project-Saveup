import { type FormEvent, useEffect, useState } from "react";
import { api } from "../api/client";
import type { BillingCycle, Subscription } from "../types";

const CYCLES: BillingCycle[] = ["weekly", "monthly", "quarterly", "yearly"];

const emptyForm = {
  name: "",
  amount: "",
  billing_cycle: "monthly" as BillingCycle,
  category: "",
  next_billing_date: new Date().toISOString().slice(0, 10),
  active: true,
  notes: "",
};

export default function Subscriptions() {
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState<string | null>(null);

  const load = () => api.subscriptions.list().then(setSubscriptions);

  useEffect(() => {
    load().finally(() => setLoading(false));
  }, []);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (!form.name || !form.amount) {
      setError("Name and amount are required.");
      return;
    }
    try {
      await api.subscriptions.create({
        name: form.name,
        amount: parseFloat(form.amount),
        billing_cycle: form.billing_cycle,
        category: form.category || null,
        next_billing_date: form.next_billing_date,
        active: form.active,
        notes: form.notes || null,
      });
      setForm(emptyForm);
      await load();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  async function handleDelete(id: number) {
    await api.subscriptions.remove(id);
    await load();
  }

  async function toggleActive(sub: Subscription) {
    await api.subscriptions.update(sub.id, { active: !sub.active });
    await load();
  }

  if (loading) return <p>Loading subscriptions...</p>;

  const activeTotal = subscriptions
    .filter((s) => s.active)
    .reduce((sum, s) => sum + s.amount, 0);

  return (
    <div>
      <h1>Subscriptions</h1>

      <form className="card form-grid" onSubmit={handleSubmit}>
        <h3>Add Subscription</h3>
        {error && <p className="error">{error}</p>}
        <div className="field-row">
          <label>
            Name
            <input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="Netflix"
            />
          </label>
          <label>
            Amount
            <input
              type="number"
              step="0.01"
              value={form.amount}
              onChange={(e) => setForm({ ...form, amount: e.target.value })}
              placeholder="15.99"
            />
          </label>
          <label>
            Billing Cycle
            <select
              value={form.billing_cycle}
              onChange={(e) =>
                setForm({ ...form, billing_cycle: e.target.value as BillingCycle })
              }
            >
              {CYCLES.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
          </label>
          <label>
            Category
            <input
              value={form.category}
              onChange={(e) => setForm({ ...form, category: e.target.value })}
              placeholder="Streaming"
            />
          </label>
          <label>
            Next Billing Date
            <input
              type="date"
              value={form.next_billing_date}
              onChange={(e) => setForm({ ...form, next_billing_date: e.target.value })}
            />
          </label>
        </div>
        <button type="submit">Add Subscription</button>
      </form>

      <div className="card" style={{ marginTop: "1rem" }}>
        <div className="list-header">
          <h3>All Subscriptions</h3>
          <span className="muted">Active total: ${activeTotal.toFixed(2)}</span>
        </div>
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Amount</th>
              <th>Cycle</th>
              <th>Category</th>
              <th>Next Bill</th>
              <th>Active</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {subscriptions.map((s) => (
              <tr key={s.id} className={s.active ? "" : "inactive-row"}>
                <td>{s.name}</td>
                <td>${s.amount.toFixed(2)}</td>
                <td>{s.billing_cycle}</td>
                <td>{s.category ?? "—"}</td>
                <td>{s.next_billing_date}</td>
                <td>
                  <input
                    type="checkbox"
                    checked={s.active}
                    onChange={() => toggleActive(s)}
                  />
                </td>
                <td>
                  <button className="link-btn" onClick={() => handleDelete(s.id)}>
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {subscriptions.length === 0 && (
              <tr>
                <td colSpan={7} className="muted">
                  No subscriptions yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
