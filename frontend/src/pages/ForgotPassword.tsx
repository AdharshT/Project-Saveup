import { useState } from "react";
import type { FormEvent } from "react";
import { Link, Navigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import { api } from "../api/client";
import logo from "../assets/logo.png";

interface FormValues {
  email: string;
  newPassword: string;
  confirmPassword: string;
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

  if (!values.newPassword) {
    errors.newPassword = "New password is required";
  } else if (values.newPassword.length < 8) {
    errors.newPassword = "Password must be at least 8 characters";
  }

  if (values.confirmPassword !== values.newPassword) {
    errors.confirmPassword = "Passwords do not match";
  }

  return errors;
}

export default function ForgotPassword() {
  const { user } = useAuth();
  const [values, setValues] = useState<FormValues>({
    email: "",
    newPassword: "",
    confirmPassword: "",
  });
  const [errors, setErrors] = useState<FormErrors>({});
  const [serverError, setServerError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);

  if (user) {
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
      await api.auth.resetPassword({
        email: values.email.trim(),
        new_password: values.newPassword,
      });
      setDone(true);
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
          <span className="muted">Remembered it?</span>
          <Link to="/login" className="ghost-btn-link">
            Log In
          </Link>
        </div>
      </header>

      <section className="signup-section signup-section-solo">
        <div className="card signup-card">
          <h3>Reset your password</h3>
          <p className="muted signup-card-lede">
            Enter the email on your account and choose a new password.
          </p>
          {done ? (
            <div>
              <p className="success">Your password has been reset.</p>
              <p className="switch-mode">
                <Link to="/login">Back to log in</Link>
              </p>
            </div>
          ) : (
            <>
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
                <div className="field-row">
                  <label>
                    New Password
                    <input
                      type="password"
                      value={values.newPassword}
                      onChange={(e) => handleChange("newPassword", e.target.value)}
                    />
                    {errors.newPassword && <span className="error">{errors.newPassword}</span>}
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
                  {submitting ? "Resetting..." : "Reset Password"}
                </button>
              </form>
              <p className="switch-mode">
                <Link to="/login">Back to log in</Link>
              </p>
            </>
          )}
        </div>
      </section>
    </div>
  );
}
