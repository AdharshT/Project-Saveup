import { useRef, useState } from "react";
import type { FormEvent } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import logo from "../assets/logo.png";

interface FormValues {
  username: string;
  name: string;
  email: string;
  password: string;
  confirmPassword: string;
}

type FormErrors = Partial<Record<keyof FormValues, string>>;

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const USERNAME_PATTERN = /^[a-zA-Z0-9_]+$/;

function validate(values: FormValues): FormErrors {
  const errors: FormErrors = {};

  if (!values.username.trim()) {
    errors.username = "Username is required";
  } else if (values.username.length < 3 || values.username.length > 20) {
    errors.username = "Username must be 3-20 characters";
  } else if (!USERNAME_PATTERN.test(values.username)) {
    errors.username = "Only letters, numbers, and underscores are allowed";
  }

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

export default function SignUp() {
  const navigate = useNavigate();
  const { user, signUp } = useAuth();
  const [values, setValues] = useState<FormValues>({
    username: "",
    name: "",
    email: "",
    password: "",
    confirmPassword: "",
  });
  const [errors, setErrors] = useState<FormErrors>({});
  const [serverError, setServerError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const wasAlreadyLoggedIn = useRef(Boolean(user)).current;
  if (wasAlreadyLoggedIn) {
    return <Navigate to="/dashboard" replace />;
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
      await signUp(values.username.trim(), values.name.trim(), values.email.trim(), values.password);
      navigate("/dashboard", { state: { welcome: "new" } });
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
          <span className="muted">Already have an account?</span>
          <Link to="/login" className="ghost-btn-link">
            Log In
          </Link>
        </div>
      </header>

      <section className="signup-section signup-section-solo">
        <div className="card signup-card">
          <h3>Sign up to get started</h3>
          <p className="muted signup-card-lede">
            Track your income, subscriptions, and spending — and always know what you can afford.
          </p>
          <form className="form-grid" onSubmit={handleSubmit} noValidate>
            {serverError && <p className="error">{serverError}</p>}
            <label>
              Username
              <input
                type="text"
                value={values.username}
                onChange={(e) => handleChange("username", e.target.value)}
                placeholder="jane_doe"
                maxLength={20}
              />
              {errors.username && <span className="error">{errors.username}</span>}
            </label>
            <label>
              Name
              <input
                type="text"
                value={values.name}
                onChange={(e) => handleChange("name", e.target.value)}
                placeholder="Jane Doe"
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
                {errors.password && <span className="error">{errors.password}</span>}
              </label>
              <label>
                Confirm Password
                <input
                  type="password"
                  value={values.confirmPassword}
                  onChange={(e) => handleChange("confirmPassword", e.target.value)}
                />
                {errors.confirmPassword && (
                  <span className="error">{errors.confirmPassword}</span>
                )}
              </label>
            </div>
            <button type="submit" disabled={submitting}>
              {submitting ? "Signing up..." : "Sign Up"}
            </button>
          </form>
          <p className="switch-mode">
            Already have an account? <Link to="/login">Log in</Link>
          </p>
        </div>
      </section>
    </div>
  );
}
