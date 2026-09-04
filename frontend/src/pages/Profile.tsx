import { useState } from "react";
import type { FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default function Profile() {
  const { user, updateEmail, signOut } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState(user?.email ?? "");
  const [error, setError] = useState("");
  const [saved, setSaved] = useState(false);

  if (!user) {
    return (
      <div>
        <h1>Profile</h1>
        <p className="muted">You need to sign up before viewing your profile.</p>
        <button type="button" onClick={() => navigate("/")}>
          Go to Sign Up
        </button>
      </div>
    );
  }

  function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setSaved(false);
    if (!EMAIL_PATTERN.test(email)) {
      setError("Enter a valid email address");
      return;
    }
    setError("");
    updateEmail(email.trim());
    setSaved(true);
  }

  function handleLogOut() {
    signOut();
  }

  return (
    <div>
      <h1>Profile</h1>
      <div className="card" style={{ maxWidth: 420 }}>
        <form className="form-grid" onSubmit={handleSubmit} noValidate>
          <label>
            Name
            <input type="text" value={user.name} disabled />
          </label>
          <label>
            Username
            <input type="text" value={user.username} disabled />
          </label>
          <label>
            Email
            <input
              type="email"
              value={email}
              onChange={(e) => {
                setEmail(e.target.value);
                setSaved(false);
              }}
            />
            {error && <span className="error">{error}</span>}
          </label>
          <button type="submit">Save Changes</button>
          {saved && <p className="muted">Email updated.</p>}
        </form>
      </div>
      <button type="button" className="link-btn" style={{ marginTop: "1rem" }} onClick={handleLogOut}>
        Log Out
      </button>
    </div>
  );
}
