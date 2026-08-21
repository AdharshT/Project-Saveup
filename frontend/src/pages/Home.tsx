import { useState } from "react";
import type { FormEvent } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import { getInitials } from "../auth/initials";
import logo from "../assets/logo.png";

const FEATURES = [
  {
    title: "Subscriptions",
    description:
      "Track every recurring cost — weekly, monthly, quarterly, or yearly — and see your total active monthly spend at a glance.",
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

interface FormValues {
  name: string;
  email: string;
  password: string;
  confirmPassword: string;
}

type FormErrors = Partial<Record<keyof FormValues, string>>;

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validate(values: FormValues): FormErrors {
  const errors: FormErrors = {};

  if (!values.name.trim()) {
    errors.name = "Name is required";
  }

  if (!values.email.trim()) {
    errors.email = "Email is required";
  } else if (!EMAIL_PATTERN.test(values.email)) {
    errors.email = "Enter a valid email address";
  }

  if (!values.password) {
    errors.password = "Password is required";
  } else if (values.password.length < 8) {
    errors.password = "Password must be at least 8 characters";
  }

  if (values.confirmPassword !== values.password) {
    errors.confirmPassword = "Passwords do not match";
  }

  return errors;
}

export default function Home() {
  const navigate = useNavigate();
  const { user, signUp } = useAuth();
  const [values, setValues] = useState<FormValues>({
    name: "",
    email: "",
    password: "",
    confirmPassword: "",
  });
  const [errors, setErrors] = useState<FormErrors>({});

  function handleChange(field: keyof FormValues, value: string) {
    setValues((prev) => ({ ...prev, [field]: value }));
  }

  function handleSubmit(event: FormEvent) {
    event.preventDefault();
    const nextErrors = validate(values);
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length === 0) {
      signUp({ name: values.name.trim(), email: values.email.trim() });
    }
  }

  function scrollToSignup() {
    document.getElementById("signup")?.scrollIntoView({ behavior: "smooth" });
  }

  return (
    <div className="landing">
      <header className="landing-topbar">
        <Link to="/" className="brand-link">
          <img src={logo} alt="Saveup" className="brand-logo" />
        </Link>
        {user ? (
          <button type="button" className="profile-btn" onClick={() => navigate("/profile")}>
            <span className="avatar">{getInitials(user.name)}</span>
            {user.name}
          </button>
        ) : (
          <button type="button" onClick={scrollToSignup}>
            Sign Up
          </button>
        )}
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

      <section className="signup-section" id="signup">
        <div className="card signup-card">
          {user ? (
            <div className="success-box">
              <h3>You're all set, {user.name.split(" ")[0]}!</h3>
              <p className="muted">Signed up with {user.email}.</p>
              <button type="button" onClick={() => navigate("/dashboard")}>
                Continue to Dashboard
              </button>
            </div>
          ) : (
            <>
              <h3>Sign up to get started</h3>
              <form className="form-grid" onSubmit={handleSubmit} noValidate>
                <label>
                  Name
                  <input
                    type="text"
                    value={values.name}
                    onChange={(e) => handleChange("name", e.target.value)}
                  />
                  {errors.name && <span className="error">{errors.name}</span>}
                </label>
                <label>
                  Email
                  <input
                    type="email"
                    value={values.email}
                    onChange={(e) => handleChange("email", e.target.value)}
                  />
                  {errors.email && <span className="error">{errors.email}</span>}
                </label>
                <div className="field-row">
                  <label>
                    Password
                    <input
                      type="password"
                      value={values.password}
                      onChange={(e) => handleChange("password", e.target.value)}
                    />
                    {errors.password && (
                      <span className="error">{errors.password}</span>
                    )}
                  </label>
                  <label>
                    Confirm Password
                    <input
                      type="password"
                      value={values.confirmPassword}
                      onChange={(e) =>
                        handleChange("confirmPassword", e.target.value)
                      }
                    />
                    {errors.confirmPassword && (
                      <span className="error">{errors.confirmPassword}</span>
                    )}
                  </label>
                </div>
                <button type="submit">Sign Up</button>
              </form>
            </>
          )}
        </div>
      </section>
    </div>
  );
}
