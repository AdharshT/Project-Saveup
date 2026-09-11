import type { Account, Subscription, Transaction } from "../types";

/**
 * account.balance is the value the user last entered as of account.created_at.
 * The live balance subtracts everything that's happened on the account since
 * then: every logged transaction, plus any active subscription charge whose
 * next_billing_date has already passed (rent/utilities/etc. included, since
 * they're just subscriptions with a category).
 */
export function liveAccountBalance(
  account: Account,
  transactions: Transaction[],
  subscriptions: Subscription[],
): number {
  const anchor = account.created_at.slice(0, 10);
  const today = new Date().toISOString().slice(0, 10);

  const spentSinceAnchor = transactions
    .filter((t) => t.account_id === account.id && t.date >= anchor)
    .reduce((sum, t) => sum + t.amount, 0);

  const chargesSinceAnchor = subscriptions
    .filter(
      (s) =>
        s.account_id === account.id &&
        s.active &&
        s.next_billing_date >= anchor &&
        s.next_billing_date <= today,
    )
    .reduce((sum, s) => sum + s.amount, 0);

  return account.balance - spentSinceAnchor - chargesSinceAnchor;
}

export function totalLiveBalance(
  accounts: Account[],
  transactions: Transaction[],
  subscriptions: Subscription[],
): number {
  return accounts.reduce(
    (sum, a) => sum + liveAccountBalance(a, transactions, subscriptions),
    0,
  );
}
