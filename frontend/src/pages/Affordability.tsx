import { type FormEvent, useState } from "react";
import { api } from "../api/client";
import type { AffordabilityResponse } from "../types";

export default function Affordability() {
  const [itemName, setItemName] = useState("");
  const [price, setPrice] = useState("");
  const [result, setResult] = useState<AffordabilityResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (!itemName || !price) {
      setError("Item name and price are required.");
      return;
    }
    setLoading(true);
    try {
      const res = await api.affordability.check(itemName, parseFloat(price));
      setResult(res);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <h1>Can I Afford This?</h1>
      <form className="card form-grid" onSubmit={handleSubmit}>
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
        <button type="submit" disabled={loading}>
          {loading ? "Checking..." : "Check Affordability"}
        </button>
      </form>

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
    </div>
  );
}
