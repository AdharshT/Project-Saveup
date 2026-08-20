import { useEffect, useState } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { api } from "../api/client";
import type { Income, MonthlyComparison, NextPaycheck, Subscription } from "../types";

function monthlyEquivalent(amount: number, cycle: string): number {
  const factors: Record<string, number> = {
    weekly: 52 / 12,
    biweekly: 26 / 12,
    semimonthly: 2,
    monthly: 1,
    quarterly: 1 / 3,
    yearly: 1 / 12,
  };
  return amount * (factors[cycle] ?? 1);
}

export default function Dashboard() {
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([]);
  const [incomes, setIncomes] = useState<Income[]>([]);
  const [nextPaychecks, setNextPaychecks] = useState<NextPaycheck[]>([]);
  const [comparison, setComparison] = useState<MonthlyComparison | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      api.subscriptions.list(),
      api.incomes.list(),
      api.incomes.next(),
      api.summary.monthly(6),
    ])
      .then(([subs, inc, next, monthly]) => {
        setSubscriptions(subs);
        setIncomes(inc);
        setNextPaychecks(next);
        setComparison(monthly);
      })
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <p>Loading dashboard...</p>;

  const monthlySubscriptionTotal = subscriptions
    .filter((s) => s.active)
    .reduce((sum, s) => sum + monthlyEquivalent(s.amount, s.billing_cycle), 0);

  const monthlyIncomeTotal = incomes
    .filter((i) => i.active)
    .reduce((sum, i) => sum + monthlyEquivalent(i.amount, i.frequency), 0);

  const chartData =
    comparison?.months.map((m) => ({ month: m.month, total: m.total })) ?? [];

  const thisMonth = comparison?.months.at(-1);
  const lastMonth = comparison?.months.at(-2);
  const spendDelta =
    thisMonth && lastMonth ? thisMonth.total - lastMonth.total : null;

  return (
    <div>
      <h1>Dashboard</h1>
      <div className="card-grid">
        <div className="card">
          <h3>Monthly Income</h3>
          <p className="stat">${monthlyIncomeTotal.toFixed(2)}</p>
        </div>
        <div className="card">
          <h3>Monthly Subscriptions</h3>
          <p className="stat">${monthlySubscriptionTotal.toFixed(2)}</p>
          <p className="muted">{subscriptions.filter((s) => s.active).length} active</p>
        </div>
        <div className="card">
          <h3>Spending This Month</h3>
          <p className="stat">${(thisMonth?.total ?? 0).toFixed(2)}</p>
          {spendDelta !== null && (
            <p className={spendDelta > 0 ? "delta-up" : "delta-down"}>
              {spendDelta > 0 ? "+" : ""}
              {spendDelta.toFixed(2)} vs last month
            </p>
          )}
        </div>
        <div className="card">
          <h3>Next Paycheck</h3>
          {nextPaychecks[0] ? (
            <>
              <p className="stat">${nextPaychecks[0].amount.toFixed(2)}</p>
              <p className="muted">
                {nextPaychecks[0].source} on {nextPaychecks[0].date}
              </p>
            </>
          ) : (
            <p className="muted">No income sources yet</p>
          )}
        </div>
      </div>

      <div className="card" style={{ marginTop: "1.5rem" }}>
        <h3>Spending by Month</h3>
        <ResponsiveContainer width="100%" height={280}>
          <BarChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="month" />
            <YAxis />
            <Tooltip formatter={(value) => `$${Number(value).toFixed(2)}`} />
            <Bar dataKey="total" fill="#2f7a4f" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
