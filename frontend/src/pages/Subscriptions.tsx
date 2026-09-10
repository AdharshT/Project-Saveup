import { type FormEvent, useEffect, useState } from "react";
import { api } from "../api/client";
import type { Account, BillingCycle, Subscription } from "../types";
import { capitalize } from "../utils/format";
import { addBillingInterval } from "../utils/subscriptions";

const HOUSING_CATEGORY = "Housing";
const CYCLES: BillingCycle[] = ["weekly", "monthly", "quarterly", "yearly"];

const SUBSCRIPTION_CATEGORIES = [
  { group: "Streaming & Media", options: ["Video", "Music", "Gaming"] },
  { group: "Productivity", options: ["Software & Apps", "Cloud Storage"] },
  { group: "Health & Fitness", options: ["Gym/Fitness", "Wellness"] },
  { group: "News & Learning", options: ["News & Media", "Education"] },
  { group: "Other", options: ["Shopping", "Utilities", "Miscellaneous"] },
] as const;

const emptyForm = {
  account_id: "",
  name: "",
  amount: "",
  billing_cycle: "monthly" as BillingCycle,
  category: SUBSCRIPTION_CATEGORIES[0].options[0] as string,
  last_payment_date: new Date().toISOString().slice(0, 10),
  active: true,
  notes: "",
};

export default function Subscriptions() {
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<number | null>(null);

  const load = () =>
    Promise.all([api.subscriptions.list(), api.accounts.list()]).then(([subs, accts]) => {
      setSubscriptions(subs.filter((s) => s.category !== HOUSING_CATEGORY));
      setAccounts(accts);
      setForm((prev) =>
        prev.account_id || accts.length === 0
          ? prev
          : { ...prev, account_id: accts[0].id.toString() },
      );
    });

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
    if (!form.account_id) {
      setError("Add an account first.");
      return;
    }
    const payload = {
      account_id: parseInt(form.account_id, 10),
      name: form.name,
      amount: parseFloat(form.amount),
      billing_cycle: form.billing_cycle,
      category: form.category,
      last_payment_date: form.last_payment_date,
      active: form.active,
      notes: form.notes || null,
    };
    try {
      if (editingId !== null) {
        await api.subscriptions.update(editingId, payload);
        setEditingId(null);
      } else {
        await api.subscriptions.create(payload);
      }
      setForm(emptyForm);
      await load();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  function handleEdit(sub: Subscription) {
    setEditingId(sub.id);
    setError(null);
    setForm({
      account_id: sub.account_id.toString(),
      name: sub.name,
      amount: sub.amount.toString(),
      billing_cycle: sub.billing_cycle,
      category: sub.category ?? SUBSCRIPTION_CATEGORIES[0].options[0],
      last_payment_date: sub.last_payment_date,
      active: sub.active,
      notes: sub.notes ?? "",
    });
  }

  function handleCancelEdit() {
    setEditingId(null);
    setError(null);
    setForm(emptyForm);
  }

  async function handleDelete(id: number) {
    if (id === editingId) handleCancelEdit();
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
        <h3>{editingId !== null ? "Edit Subscription" : "Add Subscription"}</h3>
        {error && <p className="error">{error}</p>}
        {accounts.length === 0 && (
          <p className="muted">
            Add an account on the Accounts page before adding subscriptions.
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
            <span>Name<span className="required-asterisk">*</span></span>
            <input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="Netflix"
            />
          </label>
          <label>
            <span>Amount<span className="required-asterisk">*</span></span>
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
                  {capitalize(c)}
                </option>
              ))}
            </select>
          </label>
          <label>
            Category
            <select
              value={form.category}
              onChange={(e) => setForm({ ...form, category: e.target.value })}
            >
              {SUBSCRIPTION_CATEGORIES.map((g) => (
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
            <span>Last Payment Date<span className="required-asterisk">*</span></span>
            <input
              type="date"
              value={form.last_payment_date}
              onChange={(e) => setForm({ ...form, last_payment_date: e.target.value })}
            />
          </label>
        </div>
        {form.last_payment_date && (
          <p className="muted">
            Next bill: {addBillingInterval(form.last_payment_date, form.billing_cycle)}
          </p>
        )}
        <div className="field-row">
          <button type="submit">
            {editingId !== null ? "Save Changes" : "Add Subscription"}
          </button>
          {editingId !== null && (
            <button type="button" className="ghost-btn" onClick={handleCancelEdit}>
              Cancel
            </button>
          )}
        </div>
      </form>

      <div className="card" style={{ marginTop: "1rem" }}>
        <div className="list-header">
          <h3>All Subscriptions</h3>
          <span className="muted">Active total: ${activeTotal.toFixed(2)}</span>
        </div>
        <table>
          <thead>
            <tr>
              <th>Account</th>
              <th>Name</th>
              <th>Amount</th>
              <th>Cycle</th>
              <th>Category</th>
              <th>Last Payment</th>
              <th>Next Bill</th>
              <th>Active</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {subscriptions.map((s) => (
              <tr key={s.id} className={s.active ? "" : "inactive-row"}>
                <td>{accounts.find((a) => a.id === s.account_id)?.nickname ?? "—"}</td>
                <td>{s.name}</td>
                <td>${s.amount.toFixed(2)}</td>
                <td>{capitalize(s.billing_cycle)}</td>
                <td>{s.category ?? "—"}</td>
                <td>{s.last_payment_date}</td>
                <td>{s.next_billing_date}</td>
                <td>
                  <input
                    type="checkbox"
                    checked={s.active}
                    onChange={() => toggleActive(s)}
                  />
                </td>
                <td>
                  <button className="link-btn link-btn-edit" onClick={() => handleEdit(s)}>
                    Edit
                  </button>
                  <button className="link-btn" onClick={() => handleDelete(s.id)}>
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {subscriptions.length === 0 && (
              <tr>
                <td colSpan={9} className="muted">
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
