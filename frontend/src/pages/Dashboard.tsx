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
import type {
  Account,
  Income,
  MonthlyComparison,
  NextPaycheck,
  Subscription,
  Transaction,
} from "../types";
import { effectiveIncomeAmount } from "../utils/income";
import { amountDueInMonth, monthlyEquivalent } from "../utils/subscriptions";

interface BreakdownItem {
  key: string | number;
  label: string;
  value: string;
}

interface SummaryCardProps {
  title: string;
  stat: string;
  subtext?: React.ReactNode;
  emptyText?: string;
  items: BreakdownItem[];
  expanded: boolean;
  onToggle: () => void;
  expandedSummary?: React.ReactNode;
}

function SummaryCard({
  title,
  stat,
  subtext,
  emptyText,
  items,
  expanded,
  onToggle,
  expandedSummary,
}: SummaryCardProps) {
  const clickable = items.length > 0;

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      onToggle();
    }
  }

  return (
    <div
      className={clickable ? "card summary-card clickable" : "card summary-card"}
      role={clickable ? "button" : undefined}
      tabIndex={clickable ? 0 : undefined}
      aria-expanded={clickable ? expanded : undefined}
      onClick={clickable ? onToggle : undefined}
      onKeyDown={clickable ? handleKeyDown : undefined}
    >
      <h3>{title}</h3>
      <p className="stat">{stat}</p>
      {subtext}
      {items.length === 0 && emptyText && <p className="muted">{emptyText}</p>}
      {clickable && (
        <p className="muted card-expand-hint">
          {items.length} active — {expanded ? "hide" : "view all"}
        </p>
      )}
      {clickable && expanded && expandedSummary}
      {clickable && expanded && (
        <ul className="plain-list card-breakdown">
          {items.map((item) => (
            <li key={item.key}>
              <span>{item.label}</span>
              <span>{item.value}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

export default function Dashboard() {
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([]);
  const [incomes, setIncomes] = useState<Income[]>([]);
  const [nextPaychecks, setNextPaychecks] = useState<NextPaycheck[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [comparison, setComparison] = useState<MonthlyComparison | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedAccountId, setSelectedAccountId] = useState<number | "all">("all");
  const [expanded, setExpanded] = useState({
    balance: false,
    income: false,
    subscriptions: false,
    spending: false,
    paycheck: false,
  });

  useEffect(() => {
    Promise.all([
      api.subscriptions.list(),
      api.incomes.list(),
      api.incomes.next(),
      api.transactions.list(),
      api.accounts.list(),
    ])
      .then(([subs, inc, next, txns, accts]) => {
        setSubscriptions(subs);
        setIncomes(inc);
        setNextPaychecks(next);
        setTransactions(txns);
        setAccounts(accts);
      })
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    const accountId = selectedAccountId === "all" ? undefined : selectedAccountId;
    api.summary.monthly(6, accountId).then(setComparison);
  }, [selectedAccountId]);

  if (loading) return <p>Loading dashboard...</p>;

  function toggle(key: keyof typeof expanded) {
    setExpanded((prev) => ({ ...prev, [key]: !prev[key] }));
  }

  const scopedSubscriptions =
    selectedAccountId === "all"
      ? subscriptions
      : subscriptions.filter((s) => s.account_id === selectedAccountId);
  const scopedIncomes =
    selectedAccountId === "all" ? incomes : incomes.filter((i) => i.account_id === selectedAccountId);
  const scopedTransactions =
    selectedAccountId === "all"
      ? transactions
      : transactions.filter((t) => t.account_id === selectedAccountId);
  const scopedNextPaychecks =
    selectedAccountId === "all"
      ? nextPaychecks
      : nextPaychecks.filter((p) => p.account_id === selectedAccountId);

  const selectedAccount =
    selectedAccountId === "all" ? null : accounts.find((a) => a.id === selectedAccountId) ?? null;
  const balanceTotal = selectedAccount
    ? selectedAccount.balance
    : accounts.reduce((sum, a) => sum + a.balance, 0);
  const accountItems: BreakdownItem[] = selectedAccount
    ? []
    : accounts.map((a) => ({ key: a.id, label: a.nickname, value: `$${a.balance.toFixed(2)}` }));

  const activeIncomes = scopedIncomes.filter((i) => i.active);
  const monthlyIncomeTotal = activeIncomes.reduce(
    (sum, i) => sum + monthlyEquivalent(effectiveIncomeAmount(i), i.frequency),
    0,
  );
  const incomeItems: BreakdownItem[] = activeIncomes.map((i) => ({
    key: i.id,
    label: i.source,
    value: `$${monthlyEquivalent(effectiveIncomeAmount(i), i.frequency).toFixed(2)}/mo`,
  }));

  const chartData =
    comparison?.months.map((m) => ({ month: m.month, total: m.total })) ?? [];

  const thisMonth = comparison?.months.at(-1);
  const lastMonth = comparison?.months.at(-2);
  const currentMonthStr = thisMonth?.month ?? new Date().toISOString().slice(0, 7);

  const activeSubscriptions = scopedSubscriptions.filter((s) => s.active);
  const monthlySubscriptionTotal = activeSubscriptions.reduce(
    (sum, s) => sum + monthlyEquivalent(s.amount, s.billing_cycle),
    0,
  );
  const dueThisMonthTotal = activeSubscriptions.reduce(
    (sum, s) => sum + amountDueInMonth(s.amount, s.billing_cycle, s.next_billing_date, currentMonthStr),
    0,
  );
  const subscriptionItems: BreakdownItem[] = activeSubscriptions.map((s) => ({
    key: s.id,
    label: s.name,
    value: `$${s.amount.toFixed(2)} ${s.billing_cycle} · next bill ${s.next_billing_date}`,
  }));
  const spendDelta =
    thisMonth && lastMonth ? thisMonth.total - lastMonth.total : null;

  const thisMonthTransactions = thisMonth
    ? scopedTransactions.filter((t) => t.date.slice(0, 7) === thisMonth.month)
    : [];
  const spendingItems: BreakdownItem[] = thisMonthTransactions.map((t) => ({
    key: t.id,
    label: t.category ? `${t.description} · ${t.category}` : t.description,
    value: `$${t.amount.toFixed(2)} on ${t.date}`,
  }));

  const paycheckItems: BreakdownItem[] = scopedNextPaychecks.map((p, idx) => ({
    key: idx,
    label: p.source,
    value: `$${p.amount.toFixed(2)} on ${p.date}`,
  }));

  return (
    <div>
      <div className="dashboard-header">
        <h1>Dashboard</h1>
        {accounts.length > 0 && (
          <label className="account-select">
            Account
            <select
              value={selectedAccountId}
              onChange={(e) =>
                setSelectedAccountId(e.target.value === "all" ? "all" : Number(e.target.value))
              }
            >
              <option value="all">All Accounts</option>
              {accounts.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.nickname}
                </option>
              ))}
            </select>
          </label>
        )}
      </div>
      {accounts.length === 0 && (
        <p className="muted" style={{ marginTop: "-0.75rem", marginBottom: "1.25rem" }}>
          Add a bank account on the Accounts page to start tracking balances per account.
        </p>
      )}
      <div className="card-grid">
        <SummaryCard
          title={selectedAccount ? `${selectedAccount.nickname} Balance` : "Total Balance"}
          stat={`$${balanceTotal.toFixed(2)}`}
          items={accountItems}
          expanded={expanded.balance}
          onToggle={() => toggle("balance")}
        />
        <SummaryCard
          title="Monthly Income"
          stat={`$${monthlyIncomeTotal.toFixed(2)}`}
          items={incomeItems}
          expanded={expanded.income}
          onToggle={() => toggle("income")}
        />
        <SummaryCard
          title="Monthly Subscriptions"
          stat={`$${monthlySubscriptionTotal.toFixed(2)}`}
          subtext={
            activeSubscriptions.length === 0 ? <p className="muted">0 active</p> : undefined
          }
          items={subscriptionItems}
          expanded={expanded.subscriptions}
          onToggle={() => toggle("subscriptions")}
          expandedSummary={
            <p className="card-expand-summary">
              Billed this month: <strong>${dueThisMonthTotal.toFixed(2)}</strong>
            </p>
          }
        />
        <SummaryCard
          title="Spending This Month"
          stat={`$${(thisMonth?.total ?? 0).toFixed(2)}`}
          subtext={
            spendDelta !== null ? (
              <p className={spendDelta > 0 ? "delta-up" : "delta-down"}>
                {spendDelta > 0 ? "+" : ""}
                {spendDelta.toFixed(2)} vs last month
              </p>
            ) : undefined
          }
          items={spendingItems}
          expanded={expanded.spending}
          onToggle={() => toggle("spending")}
        />
        <SummaryCard
          title="Next Paycheck"
          stat={scopedNextPaychecks[0] ? `$${scopedNextPaychecks[0].amount.toFixed(2)}` : "—"}
          emptyText="No income sources yet"
          items={paycheckItems}
          expanded={expanded.paycheck}
          onToggle={() => toggle("paycheck")}
        />
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
