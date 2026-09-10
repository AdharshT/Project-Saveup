import { type FormEvent, useEffect, useState } from "react";
import { api } from "../api/client";
import type { Account, BillingCycle, Subscription } from "../types";
import { capitalize } from "../utils/format";
import { addBillingInterval, monthlyEquivalent } from "../utils/subscriptions";

const HOUSING_CATEGORY = "Housing";
const CYCLES: BillingCycle[] = ["weekly", "monthly", "quarterly", "yearly"];

const emptyForm = {
  account_id: "",
  name: "",
  amount: "",
  billing_cycle: "monthly" as BillingCycle,
  last_payment_date: new Date().toISOString().slice(0, 10),
  active: true,
};

export default function Rent() {
  const [items, setItems] = useState<Subscription[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<number | null>(null);

  const load = () =>
    Promise.all([api.subscriptions.list(), api.accounts.list()]).then(([subs, accts]) => {
      setItems(subs.filter((s) => s.category === HOUSING_CATEGORY));
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
      category: HOUSING_CATEGORY,
      last_payment_date: form.last_payment_date,
      active: form.active,
      notes: null,
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

  function handleEdit(item: Subscription) {
    setEditingId(item.id);
    setError(null);
    setForm({
      account_id: item.account_id.toString(),
      name: item.name,
      amount: item.amount.toString(),
      billing_cycle: item.billing_cycle,
      last_payment_date: item.last_payment_date,
      active: item.active,
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
        <h3>{editingId !== null ? "Edit Rent or Utility" : "Add Rent or Utility"}</h3>
        {error && <p className="error">{error}</p>}
        {accounts.length === 0 && (
          <p className="muted">
            Add an account on the Accounts page before adding rent or utilities.
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
              placeholder="Rent"
            />
          </label>
          <label>
            <span>Amount<span className="required-asterisk">*</span></span>
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
                  {capitalize(c)}
                </option>
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
          <button type="submit">{editingId !== null ? "Save Changes" : "Add"}</button>
          {editingId !== null && (
            <button type="button" className="ghost-btn" onClick={handleCancelEdit}>
              Cancel
            </button>
          )}
        </div>
      </form>

      <div className="card" style={{ marginTop: "1rem" }}>
        <h3>Rent &amp; Utilities</h3>
        <table>
          <thead>
            <tr>
              <th>Account</th>
              <th>Name</th>
              <th>Amount</th>
              <th>Cycle</th>
              <th>Monthly Equivalent</th>
              <th>Last Payment</th>
              <th>Next Bill</th>
              <th>Active</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((i) => (
              <tr key={i.id} className={i.active ? "" : "inactive-row"}>
                <td>{accounts.find((a) => a.id === i.account_id)?.nickname ?? "—"}</td>
                <td>{i.name}</td>
                <td>${i.amount.toFixed(2)}</td>
                <td>{capitalize(i.billing_cycle)}</td>
                <td>${monthlyEquivalent(i.amount, i.billing_cycle).toFixed(2)}</td>
                <td>{i.last_payment_date}</td>
                <td>{i.next_billing_date}</td>
                <td>
                  <input
                    type="checkbox"
                    checked={i.active}
                    onChange={() => toggleActive(i)}
                  />
                </td>
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
            {items.length === 0 && (
              <tr>
                <td colSpan={9} className="muted">
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
