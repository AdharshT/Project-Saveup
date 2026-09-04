import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import { getInitials } from "../auth/initials";
import logo from "../assets/logo.png";

const FEATURES = [
  {
    title: "Accounts",
    description:
      "Manage all your bank accounts in one place. Add multiple accounts to easily track balances, income, and spending across each account.",
  },

  {
    title: "Subscriptions",
    description:
      "Track every recurring cost — weekly, monthly, quarterly, or yearly — and see your total active monthly spend at a glance.",
  },
  
  {
    title: "Rent and Utilites",
    description:
    "Tracks total monthly housing costs — rent plus utilities and other recurring fees — normalized into one accurate monthly number.",
  },
  
  {
    title: "Income",
    description:
      "Add one or more income sources with a pay frequency and always know when your next paycheck lands.",
  },
  
  {
    title: "Spending",
    description:
      "Log transactions by category and date, then track month-over-month totals with a trend chart.",
  },
  
  {
    title: "Can I Afford This?",
    description:
      "Check whether a purchase fits your discretionary budget — income minus subscriptions minus what you've already spent this month.",
  },

];

export default function Home() {
  const navigate = useNavigate();
  const { user } = useAuth();

  return (
  <div className="landing">
    <header className="landing-topbar">
      <Link to="/" className="brand-link">
        <img src={logo} alt="Saveup" className="brand-logo" />
      </Link>

      {user ? (
        <button
          type="button"
          className="profile-btn"
          onClick={() => navigate("/profile")}
        >
          <span className="avatar">{getInitials(user.name)}</span>
          {user.name}
        </button>
      ) : null}
      </header>

      <section className="hero">
        <h1>Know exactly where your money goes.</h1>
        <p className="tagline">
          Saveup is a manual budget tracker for your subscriptions, income, and
          spending — no bank account linking required. See what's coming in,
          what's going out, and whether you can afford your next purchase.
        </p>
      </section>

      <div className="feature-grid">
        {FEATURES.map((feature) => (
          <div className="card" key={feature.title}>
            <h3>{feature.title}</h3>
            <p className="muted">{feature.description}</p>
          </div>
        ))}
      </div>

      <section className="signup-section">
        <div className="card signup-card">
          {user ? (
            <div className="success-box">
              <h3>You're all set, {user.name}!</h3>
              <p className="muted">Signed in as {user.email}.</p>
              <button type="button" onClick={() => navigate("/dashboard")}>
                Continue to Dashboard
              </button>
            </div>
          ) : (
            <div className="success-box">
              <h3>Ready to get a handle on your money?</h3>
              <p className="muted">Create an account or log back in to pick up where you left off.</p>
              <div className="cta-row">
                <button type="button" onClick={() => navigate("/signup")}>
                  Sign Up
                </button>
                <button type="button" className="ghost-btn" onClick={() => navigate("/login")}>
                  Log In
                </button>
              </div>
            </div>
          )}
        </div>
      </section>
    </div>
  );
}
