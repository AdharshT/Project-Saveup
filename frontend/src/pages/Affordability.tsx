import { type FormEvent, useEffect, useState } from "react";
import { api } from "../api/client";
import type { AffordabilityResponse, BasketItem } from "../types";

export default function Affordability() {
  const [itemName, setItemName] = useState("");
  const [price, setPrice] = useState("");
  const [basket, setBasket] = useState<BasketItem[]>([]);
  const [nextId, setNextId] = useState(1);
  const [editingBasketId, setEditingBasketId] = useState<number | null>(null);

  const [result, setResult] = useState<AffordabilityResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const [history, setHistory] = useState<AffordabilityResponse[]>([]);
  const [historyLoading, setHistoryLoading] = useState(true);
  const [expandedHistoryId, setExpandedHistoryId] = useState<number | null>(null);

  useEffect(() => {
    api.affordability
      .history()
      .then(setHistory)
      .finally(() => setHistoryLoading(false));
  }, []);

  function handleAddItem(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setResult(null);
    if (!itemName || !price) {
      setError("Item name and price are required.");
      return;
    }
    if (editingBasketId !== null) {
      setBasket((prev) =>
        prev.map((item) =>
          item.id === editingBasketId ? { ...item, name: itemName, price: parseFloat(price) } : item,
        ),
      );
      setEditingBasketId(null);
    } else {
      setBasket((prev) => [...prev, { id: nextId, name: itemName, price: parseFloat(price) }]);
      setNextId((id) => id + 1);
    }
    setItemName("");
    setPrice("");
  }

  function handleEditItem(item: BasketItem) {
    setEditingBasketId(item.id);
    setError(null);
    setItemName(item.name);
    setPrice(item.price.toString());
  }

  function handleCancelEditItem() {
    setEditingBasketId(null);
    setItemName("");
    setPrice("");
  }

  function handleRemoveItem(id: number) {
    if (id === editingBasketId) handleCancelEditItem();
    setBasket((prev) => prev.filter((item) => item.id !== id));
    setResult(null);
  }

  async function handleCheck() {
    setError(null);
    if (basket.length === 0) {
      setError("Add at least one item to your basket first.");
      return;
    }
    setLoading(true);
    try {
      const res = await api.affordability.check(
        basket.map((item) => ({ name: item.name, price: item.price })),
      );
      setResult(res);
      setHistory((prev) => [res, ...prev]);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setLoading(false);
    }
  }

  async function handleDeleteHistory(id: number) {
    await api.affordability.removeHistory(id);
    setHistory((prev) => prev.filter((entry) => entry.id !== id));
    if (result?.id === id) setResult(null);
  }

  const basketTotal = basket.reduce((sum, item) => sum + item.price, 0);

  return (
    <div>
      <h1>Can I Afford This?</h1>
      <p className="muted" style={{ marginTop: "-1rem", marginBottom: "1.25rem" }}>
        Add one or more items to your basket, then check whether you can afford all of them
        together this month. Past checks are saved below.
      </p>

      <form className="card form-grid" onSubmit={handleAddItem}>
        <h3>{editingBasketId !== null ? "Edit Basket Item" : "Add Item to Basket"}</h3>
        {error && <p className="error">{error}</p>}
        <div className="field-row">
          <label>
            Item
            <input
              value={itemName}
              onChange={(e) => setItemName(e.target.value)}
              placeholder="New headphones"
            />
          </label>
          <label>
            Price
            <input
              type="number"
              step="0.01"
              value={price}
              onChange={(e) => setPrice(e.target.value)}
              placeholder="199.99"
            />
          </label>
        </div>
        <div className="field-row">
          <button type="submit">
            {editingBasketId !== null ? "Save Changes" : "Add to Basket"}
          </button>
          {editingBasketId !== null && (
            <button type="button" className="ghost-btn" onClick={handleCancelEditItem}>
              Cancel
            </button>
          )}
        </div>
      </form>

      <div className="card" style={{ marginTop: "1rem" }}>
        <div className="list-header">
          <h3>Basket</h3>
          <span className="muted">Total: ${basketTotal.toFixed(2)}</span>
        </div>
        <ul className="plain-list basket-list">
          {basket.map((item) => (
            <li key={item.id} className="list-header">
              <span>{item.name}</span>
              <span>
                ${item.price.toFixed(2)}{" "}
                <button className="link-btn link-btn-edit" onClick={() => handleEditItem(item)}>
                  Edit
                </button>
                <button className="link-btn" onClick={() => handleRemoveItem(item.id)}>
                  Remove
                </button>
              </span>
            </li>
          ))}
        </ul>
        {basket.length === 0 && <p className="muted">Your basket is empty.</p>}
        <button
          type="button"
          style={{ marginTop: "1rem" }}
          disabled={loading || basket.length === 0}
          onClick={handleCheck}
        >
          {loading ? "Checking..." : "Check Affordability"}
        </button>
      </div>

      {result && (
        <div className={`card result-card ${result.can_afford ? "afford-yes" : "afford-no"}`}>
          <h3>{result.can_afford ? "You can afford it" : "This may be a stretch"}</h3>
          <p>{result.message}</p>
          <div className="card-grid">
            <div>
              <span className="muted">Monthly Income</span>
              <p className="stat-sm">${result.monthly_income.toFixed(2)}</p>
            </div>
            <div>
              <span className="muted">Monthly Subscriptions</span>
              <p className="stat-sm">${result.monthly_subscription_cost.toFixed(2)}</p>
            </div>
            <div>
              <span className="muted">Spent This Month</span>
              <p className="stat-sm">${result.spending_this_month.toFixed(2)}</p>
            </div>
            <div>
              <span className="muted">Discretionary Balance</span>
              <p className="stat-sm">${result.discretionary_balance.toFixed(2)}</p>
            </div>
            <div>
              <span className="muted">Balance After Purchase</span>
              <p className="stat-sm">${result.balance_after_purchase.toFixed(2)}</p>
            </div>
          </div>
        </div>
      )}

      <div className="card" style={{ marginTop: "1rem" }}>
        <h3>History</h3>
        {historyLoading && <p className="muted">Loading history...</p>}
        {!historyLoading && history.length === 0 && (
          <p className="muted">No past checks yet.</p>
        )}
        {!historyLoading && history.length > 0 && (
          <ul className="plain-list basket-list">
            {history.map((entry) => {
              const expanded = expandedHistoryId === entry.id;
              const names = entry.items.map((i) => i.name).join(", ");
              return (
                <li key={entry.id}>
                  <div className="list-header">
                    <button
                      type="button"
                      className="history-toggle"
                      onClick={() => setExpandedHistoryId(expanded ? null : entry.id)}
                    >
                      {new Date(entry.created_at).toLocaleDateString()} — {names}
                    </button>
                    <span>
                      <span className={entry.can_afford ? "delta-down" : "delta-up"}>
                        {entry.can_afford ? "Affordable" : "Over budget"}
                      </span>{" "}
                      ${entry.total_price.toFixed(2)}{" "}
                      <button
                        className="link-btn"
                        onClick={() => handleDeleteHistory(entry.id)}
                      >
                        Delete
                      </button>
                    </span>
                  </div>
                  {expanded && (
                    <ul className="plain-list card-breakdown">
                      {entry.items.map((item) => (
                        <li key={item.id}>
                          <span>{item.name}</span>
                          <span>${item.price.toFixed(2)}</span>
                        </li>
                      ))}
                    </ul>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </div>
    </div>
  );
}
