import { useState } from "react";
import type { FormEvent } from "react";
import { Link, Navigate, useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import logo from "../assets/logo.png";

interface FormValues {
  email: string;
  password: string;
}

type FormErrors = Partial<Record<keyof FormValues, string>>;

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validate(values: FormValues): FormErrors {
  const errors: FormErrors = {};

  if (!values.email.trim()) {
    errors.email = "Email is required";
  } else if (!EMAIL_PATTERN.test(values.email)) {
    errors.email = "Enter a valid email address";
  }

  if (!values.password) {
    errors.password = "Password is required";
  }

  return errors;
}

export default function Login() {
  const navigate = useNavigate();
  const location = useLocation();
  const { user, signIn } = useAuth();
  const [values, setValues] = useState<FormValues>({ email: "", password: "" });
  const [errors, setErrors] = useState<FormErrors>({});
  const [serverError, setServerError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const from = (location.state as { from?: { pathname: string } } | null)?.from?.pathname;

  if (user) {
    return <Navigate to={from ?? "/dashboard"} replace />;
  }

  function handleChange(field: keyof FormValues, value: string) {
    setValues((prev) => ({ ...prev, [field]: value }));
  }

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setServerError(null);
    const nextErrors = validate(values);
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    setSubmitting(true);
    try {
      await signIn(values.email.trim(), values.password);
      navigate(from ?? "/dashboard", { replace: true });
    } catch (err) {
      setServerError((err as Error).message);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="landing">
      <header className="landing-topbar">
        <Link to="/" className="brand-link">
          <img src={logo} alt="Saveup" className="brand-logo" />
        </Link>
        <div className="topbar-actions">
          <span className="muted">New here?</span>
          <Link to="/signup" className="ghost-btn-link">
            Sign Up
          </Link>
        </div>
      </header>

      <section className="signup-section signup-section-solo">
        <div className="card signup-card">
          <h3>Log in to your account</h3>
          <p className="muted signup-card-lede">Pick up right where you left off.</p>
          <form className="form-grid" onSubmit={handleSubmit} noValidate>
            {serverError && <p className="error">{serverError}</p>}
            <label>
              Email
              <input
                type="email"
                value={values.email}
                onChange={(e) => handleChange("email", e.target.value)}
              />
              {errors.email && <span className="error">{errors.email}</span>}
            </label>
            <label>
              Password
              <input
                type="password"
                value={values.password}
                onChange={(e) => handleChange("password", e.target.value)}
              />
              {errors.password && <span className="error">{errors.password}</span>}
            </label>
            <button type="submit" disabled={submitting}>
              {submitting ? "Logging in..." : "Log In"}
            </button>
          </form>
          <p className="switch-mode">
            New here? <Link to="/signup">Sign up</Link>
          </p>
        </div>
      </section>
    </div>
  );
}
