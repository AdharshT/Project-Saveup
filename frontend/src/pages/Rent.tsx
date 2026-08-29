import { type FormEvent, useEffect, useState } from "react";
import { api } from "../api/client";
import type { BillingCycle, Subscription } from "../types";
import { monthlyEquivalent } from "../utils/subscriptions";

const HOUSING_CATEGORY = "Housing";
const CYCLES: BillingCycle[] = ["weekly", "monthly", "quarterly", "yearly"];

const emptyForm = {
  name: "",
  amount: "",
  billing_cycle: "monthly" as BillingCycle,
  next_billing_date: new Date().toISOString().slice(0, 10),
  active: true,
};

export default function Rent() {
  const [items, setItems] = useState<Subscription[]>([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState<string | null>(null);

  const load = () =>
    api.subscriptions
      .list()
      .then((subs) => setItems(subs.filter((s) => s.category === HOUSING_CATEGORY)));

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
        category: HOUSING_CATEGORY,
        next_billing_date: form.next_billing_date,
        active: form.active,
        notes: null,
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

  async function toggleActive(item: Subscription) {
    await api.subscriptions.update(item.id, { active: !item.active });
    await load();
  }

  if (loading) return <p>Loading rent & utilities...</p>;

  const monthlyTotal = items
    .filter((i) => i.active)
    .reduce((sum, i) => sum + monthlyEquivalent(i.amount, i.billing_cycle), 0);

  return (
    <div>
      <h1>Rent &amp; Utilities</h1>
      <p className="muted" style={{ marginTop: "-1rem", marginBottom: "1.25rem" }}>
        Rent and each utility or fee are entered the same way as any other recurring cost —
        a name, an amount, and how often it's billed. Anything billed less often than monthly
        (like a yearly renters insurance premium) is automatically averaged down to a monthly
        figure so it fits alongside the rest.
      </p>

      <div className="card">
        <h3>Total Monthly Housing Cost</h3>
        <p className="stat">${monthlyTotal.toFixed(2)}</p>
        <p className="muted">
          {items.filter((i) => i.active).length} active item
          {items.filter((i) => i.active).length === 1 ? "" : "s"}
        </p>
      </div>

      <form className="card form-grid" onSubmit={handleSubmit} style={{ marginTop: "1rem" }}>
        <h3>Add Rent or Utility</h3>
        {error && <p className="error">{error}</p>}
        <div className="field-row">
          <label>
            Name
            <input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="Rent"
            />
          </label>
          <label>
            Amount
            <input
              type="number"
              step="0.01"
              value={form.amount}
              onChange={(e) => setForm({ ...form, amount: e.target.value })}
              placeholder="1800.00"
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
            Next Billing Date
            <input
              type="date"
              value={form.next_billing_date}
              onChange={(e) => setForm({ ...form, next_billing_date: e.target.value })}
            />
          </label>
        </div>
        <button type="submit">Add</button>
      </form>

      <div className="card" style={{ marginTop: "1rem" }}>
        <h3>Rent &amp; Utilities</h3>
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Amount</th>
              <th>Cycle</th>
              <th>Monthly Equivalent</th>
              <th>Next Bill</th>
              <th>Active</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((i) => (
              <tr key={i.id} className={i.active ? "" : "inactive-row"}>
                <td>{i.name}</td>
                <td>${i.amount.toFixed(2)}</td>
                <td>{i.billing_cycle}</td>
                <td>${monthlyEquivalent(i.amount, i.billing_cycle).toFixed(2)}</td>
                <td>{i.next_billing_date}</td>
                <td>
                  <input
                    type="checkbox"
                    checked={i.active}
                    onChange={() => toggleActive(i)}
                  />
                </td>
                <td>
                  <button className="link-btn" onClick={() => handleDelete(i.id)}>
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr>
                <td colSpan={7} className="muted">
                  No rent or utilities added yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
