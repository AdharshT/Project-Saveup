import { type FormEvent, useEffect, useState } from "react";
import { api } from "../api/client";
import type { Account, AccountType, Bank } from "../types";
import { capitalize } from "../utils/format";

const ACCOUNT_TYPES: AccountType[] = ["checking", "savings", "credit"];

const BANK_OPTIONS = [
  "Chase",
  "Bank of America",
  "Wells Fargo",
  "Citibank",
  "U.S. Bank",
  "PNC Bank",
  "Truist",
  "TD Bank",
  "Capital One",
];
const OTHER_BANK = "__other__";

const emptyBankForm = { name: "" };

const emptyAccountForm = {
  bank_id: "",
  type: "checking" as AccountType,
  last4: "",
  balance: "",
};

function autoNickname(bankName: string, last4: string): string {
  return last4 ? `${bankName} ••${last4}` : bankName;
}

export default function Accounts() {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [banks, setBanks] = useState<Bank[]>([]);
  const [loading, setLoading] = useState(true);

  const [bankForm, setBankForm] = useState(emptyBankForm);
  const [bankError, setBankError] = useState<string | null>(null);
  const [editingBankId, setEditingBankId] = useState<number | null>(null);
  const [useCustomBank, setUseCustomBank] = useState(false);

  const [form, setForm] = useState(emptyAccountForm);
  const [error, setError] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<number | null>(null);

  const load = () =>
    Promise.all([api.accounts.list(), api.banks.list()]).then(([accts, bnks]) => {
      setAccounts(accts);
      setBanks(bnks);
      setForm((prev) =>
        prev.bank_id || bnks.length === 0 ? prev : { ...prev, bank_id: bnks[0].id.toString() },
      );
    });

  useEffect(() => {
    load().finally(() => setLoading(false));
  }, []);

  async function handleBankSubmit(e: FormEvent) {
    e.preventDefault();
    setBankError(null);
    if (!bankForm.name) {
      setBankError("Bank name is required.");
      return;
    }
    try {
      if (editingBankId !== null) {
        await api.banks.update(editingBankId, bankForm);
        setEditingBankId(null);
      } else {
        await api.banks.create(bankForm);
      }
      setBankForm(emptyBankForm);
      setUseCustomBank(false);
      await load();
    } catch (err) {
      setBankError((err as Error).message);
    }
  }

  function handleEditBank(bank: Bank) {
    setEditingBankId(bank.id);
    setBankError(null);
    setBankForm({ name: bank.name });
    setUseCustomBank(!BANK_OPTIONS.includes(bank.name));
  }

  function handleCancelBankEdit() {
    setUseCustomBank(false);
    setEditingBankId(null);
    setBankError(null);
    setBankForm(emptyBankForm);
  }

  async function handleDeleteBank(id: number) {
    setBankError(null);
    try {
      if (id === editingBankId) handleCancelBankEdit();
      await api.banks.remove(id);
      await load();
    } catch (err) {
      setBankError((err as Error).message);
    }
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (!form.bank_id) {
      setError("Add a bank first.");
      return;
    }
    const selectedBankName = banks.find((b) => b.id === parseInt(form.bank_id, 10))?.name ?? "";
    const payload = {
      bank_id: parseInt(form.bank_id, 10),
      nickname: autoNickname(selectedBankName, form.last4),
      type: form.type,
      last4: form.last4 || null,
      balance: form.balance ? parseFloat(form.balance) : 0,
    };
    try {
      if (editingId !== null) {
        await api.accounts.update(editingId, payload);
        setEditingId(null);
      } else {
        await api.accounts.create(payload);
      }
      setForm((prev) => ({ ...emptyAccountForm, bank_id: prev.bank_id }));
      await load();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  function handleEdit(account: Account) {
    setEditingId(account.id);
    setError(null);
    setForm({
      bank_id: account.bank_id.toString(),
      type: account.type ?? "checking",
      last4: account.last4 ?? "",
      balance: account.balance.toString(),
    });
  }

  function handleCancelEdit() {
    setEditingId(null);
    setError(null);
    setForm((prev) => ({ ...emptyAccountForm, bank_id: prev.bank_id }));
  }

  async function handleDelete(id: number) {
    setError(null);
    try {
      if (id === editingId) handleCancelEdit();
      await api.accounts.remove(id);
      await load();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  if (loading) return <p>Loading accounts...</p>;

  const totalBalance = accounts.reduce((sum, a) => sum + a.balance, 0);
  const bankName = (bankId: number) => banks.find((b) => b.id === bankId)?.name ?? "—";

  return (
    <div>
      <h1>Accounts</h1>
      <p className="muted" style={{ marginTop: "-1rem", marginBottom: "1.25rem" }}>
        Add each bank you use, then add an account under it for every place your money lives.
        Subscriptions, income, and spending are each assigned to one account, so the Dashboard
        can show you totals for a single account or everything combined.
      </p>

      <div className="card">
        <h3>Total Balance</h3>
        <p className="stat">${totalBalance.toFixed(2)}</p>
        <p className="muted">
          {accounts.length} account{accounts.length === 1 ? "" : "s"}
        </p>
      </div>

      <form className="card form-grid" onSubmit={handleBankSubmit} style={{ marginTop: "1rem" }}>
        <h3>{editingBankId !== null ? "Edit Bank" : "Add Bank"}</h3>
        {bankError && <p className="error">{bankError}</p>}
        <div className="field-row">
          <label>
            Bank Name
            <select
              value={useCustomBank ? OTHER_BANK : bankForm.name}
              onChange={(e) => {
                if (e.target.value === OTHER_BANK) {
                  setUseCustomBank(true);
                  setBankForm({ name: "" });
                } else {
                  setUseCustomBank(false);
                  setBankForm({ name: e.target.value });
                }
              }}
            >
              <option value="" disabled>
                Select a bank
              </option>
              {BANK_OPTIONS.map((b) => (
                <option key={b} value={b}>
                  {b}
                </option>
              ))}
              <option value={OTHER_BANK}>Other</option>
            </select>
          </label>
          {useCustomBank && (
            <label>
              Custom Bank Name
              <input
                value={bankForm.name}
                onChange={(e) => setBankForm({ name: e.target.value })}
                placeholder="My Credit Union"
              />
            </label>
          )}
        </div>
        <div className="field-row">
          <button type="submit">{editingBankId !== null ? "Save Changes" : "Add Bank"}</button>
          {editingBankId !== null && (
            <button type="button" className="ghost-btn" onClick={handleCancelBankEdit}>
              Cancel
            </button>
          )}
        </div>
      </form>

      {banks.length > 0 && (
        <div className="card" style={{ marginTop: "1rem" }}>
          <h3>Banks</h3>
          <ul className="plain-list">
            {banks.map((b) => (
              <li key={b.id} className="list-header">
                <span>{b.name}</span>
                <span>
                  <button className="link-btn link-btn-edit" onClick={() => handleEditBank(b)}>
                    Edit
                  </button>
                  <button className="link-btn" onClick={() => handleDeleteBank(b.id)}>
                    Delete
                  </button>
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}

      <form className="card form-grid" onSubmit={handleSubmit} style={{ marginTop: "1rem" }}>
        <h3>{editingId !== null ? "Edit Account" : "Add Account"}</h3>
        {error && <p className="error">{error}</p>}
        {banks.length === 0 && <p className="muted">Add a bank above before adding accounts.</p>}
        <div className="field-row">
          <label>
            Bank
            <select
              value={form.bank_id}
              onChange={(e) => setForm({ ...form, bank_id: e.target.value })}
            >
              {banks.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            Type
            <select
              value={form.type}
              onChange={(e) => setForm({ ...form, type: e.target.value as AccountType })}
            >
              {ACCOUNT_TYPES.map((t) => (
                <option key={t} value={t}>
                  {capitalize(t)}
                </option>
              ))}
            </select>
          </label>
          <label>
            Last 4
            <input
              value={form.last4}
              onChange={(e) => setForm({ ...form, last4: e.target.value })}
              placeholder="0042"
              maxLength={4}
            />
          </label>
          <label>
            Balance
            <input
              type="number"
              step="0.01"
              value={form.balance}
              onChange={(e) => setForm({ ...form, balance: e.target.value })}
              placeholder="1500.00"
            />
          </label>
        </div>
        <div className="field-row">
          <button type="submit">{editingId !== null ? "Save Changes" : "Add Account"}</button>
          {editingId !== null && (
            <button type="button" className="ghost-btn" onClick={handleCancelEdit}>
              Cancel
            </button>
          )}
        </div>
      </form>

      <div className="card" style={{ marginTop: "1rem" }}>
        <h3>All Accounts</h3>
        <table>
          <thead>
            <tr>
              <th>Bank</th>
              <th>Type</th>
              <th>Last 4</th>
              <th>Balance</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {accounts.map((a) => (
              <tr key={a.id}>
                <td>{bankName(a.bank_id)}</td>
                <td>{a.type ? capitalize(a.type) : "—"}</td>
                <td>{a.last4 ? `••${a.last4}` : "—"}</td>
                <td>${a.balance.toFixed(2)}</td>
                <td>
                  <button className="link-btn link-btn-edit" onClick={() => handleEdit(a)}>
                    Edit
                  </button>
                  <button className="link-btn" onClick={() => handleDelete(a.id)}>
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {accounts.length === 0 && (
              <tr>
                <td colSpan={5} className="muted">
                  No accounts yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
